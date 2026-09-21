---
name: file-pipeline-patterns
description: |
  End-to-end file upload pipeline for .NET 10: SeaweedFS object storage, ImageSharp processing, nClam virus scanning, saga-driven upload state machine (quarantine → scan → process → private/public). Covers presigned uploads via FastEndpoints, Upload aggregate persistence, image-variant generation, blob lifecycle, and ABAC for file access. Use for any feature that accepts user uploads or serves user-owned files.
when_to_load:
  - Task mentions: upload, file, attachment, image, blob, storage, seaweedfs, s3, presigned, virus, scan, clamav, imagesharp, resize, thumbnail, quarantine
  - Files touched: any *Upload*.cs, *File*.cs, *Image*.cs, *Attachment*.cs, *Storage*.cs, *.Adapters.SeaweedFs/*, *.Adapters.Nclam/*, *.Adapters.ImageSharp/*
co_loads_with:
  - backend-architecture (canonical seams, structure, markers, events model — read first)
  - backend-feature-patterns (handler + aggregate shape)
  - orchestration-patterns (saga decision rule + saga authoring shape)
  - data-access-patterns (Upload aggregate write path + outbox binding)
references:
  - authorization-patterns (ABAC for owner-scoped file access)
  - caching-patterns (thumbnail / signed-URL caching)
  - api-endpoint-patterns (presigned-upload endpoint + idempotency)
  - integration-adapter-patterns (scanner / storage adapter authoring with resilience)
---

# File-Pipeline Patterns

Read `backend-architecture` first — it owns the seam catalog, the building-blocks/module structure, the
comment-marker index, the domain/integration event model, and the NetArchTest invariants. This skill applies
them to the file-upload pipeline. Storage / image / scan are **edges** behind ports; the upload state machine
is a saga whose authoring shape lives in `orchestration-patterns` and whose runtime registration lives in
`infrastructure-wiring`.

## 1. Mental model

```
   presign endpoint (api-endpoint-patterns) → signed URL to quarantine + Upload aggregate ID (Pending)
        ▼
   Client PUTs bytes directly to SeaweedFS quarantine
        ▼
   complete endpoint → command MarkUploadQuarantined (via IAppCommandBus.Send)
        ▼
   command handler persists Upload (Quarantined); raises UploadQuarantinedEvent → outbox
        ▼
   UploadProcessingSaga:
     UploadQuarantinedEvent → IVirusScanService.ScanAsync
        clean    → UploadScanCleanEvent
        infected → UploadScanInfectedEvent (file purged, aggregate Rejected, saga ends)
     UploadScanCleanEvent → if image: IImageProcessor.ProcessAsync (resize, EXIF strip) + variant upload
        → UploadProcessedEvent
     UploadProcessedEvent → MoveAsync quarantine → private|public
        → aggregate Available; UploadAvailableIntegrationEvent → outbox
```

**Rule:** every uploaded byte transits the `quarantine` bucket first; nothing reaches `private` or `public` until scan + process complete.

## 2. Bucket strategy

| Bucket | Purpose | Access | Retention |
|---|---|---|---|
| `quarantine` | Uploaded, unscanned | Signed PUT only (write); read by scanner | 24h max (lifecycle policy auto-purges abandoned uploads) |
| `private` | Scanned-clean, owner-scoped | Signed read URLs only (TTL ≤ 1h) | aggregate-lifetime |
| `public` | Scanned-clean, world-readable | CDN-fronted; immutable, content-addressed URLs (`<hash>/<filename>`) | aggregate-lifetime |

A file moves `quarantine → private` OR `quarantine → public` — never `private ↔ public` directly. Per-bucket versioning, encryption-at-rest, and lifecycle config is a deployment concern, not a skill concern. Concrete bucket names are project vocabulary (`.specify/memory/system-context.md`); app code uses the `Bucket` enum, never a string literal.

## 3. Port: IFileStorageService

Interface in Application; SeaweedFS implementation in `YourContext.Adapters.SeaweedFs`. App code never touches the S3 SDK directly. Boundary methods return `Result` / `Result<T>` — no throwing for expected failures (`backend-architecture §2`).

```csharp
namespace YourContext.Application.Files;

public enum Bucket { Quarantine, Private, Public }

public sealed record UploadCredentials(string PresignedUrl, IReadOnlyDictionary<string, string> FormFields, DateTimeOffset ExpiresAt);

public interface IFileStorageService
{
    Task<Result<UploadCredentials>> GetUploadCredentialsAsync(Bucket bucket, string key, TimeSpan ttl, CancellationToken ct);
    Task<Result<Stream>> OpenReadAsync(Bucket bucket, string key, CancellationToken ct);
    Task<Result> MoveAsync(Bucket from, string fromKey, Bucket to, string toKey, CancellationToken ct);
    Task<Result> DeleteAsync(Bucket bucket, string key, CancellationToken ct);
    Task<Result<string>> GetSignedReadUrlAsync(Bucket bucket, string key, TimeSpan ttl, CancellationToken ct);
}
```

## 4. Port: IImageProcessor

Interface in Application; ImageSharp implementation in `YourContext.Adapters.ImageSharp`. The caller (the saga) chooses destination bucket + key; the processor only produces bytes. Returns `Result<ProcessedImage>` — a decode failure on a corrupt/spoofed file is an expected boundary outcome, not an exception.

```csharp
namespace YourContext.Application.Files;

public sealed record ImageVariantSpec(string Name, int MaxWidth, int MaxHeight, string Format, int Quality);
public sealed record ImageProcessingOptions(IReadOnlyList<ImageVariantSpec> Variants, bool StripExif = true);
public sealed record ProcessedImageVariant(string Name, ReadOnlyMemory<byte> Bytes, string ContentType, int Width, int Height);
public sealed record ProcessedImage(IReadOnlyList<ProcessedImageVariant> Variants);

public interface IImageProcessor
{
    Task<Result<ProcessedImage>> ProcessAsync(Stream source, ImageProcessingOptions options, CancellationToken ct);
}
```

## 5. Port: IVirusScanService

Interface in Application; nClam implementation in `YourContext.Adapters.Nclam`. The caller streams the source — no full-file buffering. Returns `Result<ScanResult>`; a transport-level scanner outage surfaces as `Error.Failure` so the saga can retry (§8).

```csharp
namespace YourContext.Application.Files;

public enum ScanOutcome { Clean, Infected, Error }
public sealed record ScanResult(ScanOutcome Outcome, string? SignatureName = null);

public interface IVirusScanService
{
    Task<Result<ScanResult>> ScanAsync(Stream source, CancellationToken ct);
}
```

Timeout: 30s per scan. Circuit-break on repeated `Error` outcomes — see `integration-adapter-patterns` §5 (standard resilience pipeline) for the wiring; the nClam adapter consumes it.

## 6. Presigned-upload endpoint

The HTTP edge follows `api-endpoint-patterns` — bind, dispatch via `IAppCommandBus.Send`, map the `Result<T>`
to HTTP through the single extension. The endpoint never injects Wolverine `IMessageBus` (NetArchTest invariant
#1, `backend-architecture §8`).

```csharp
namespace YourContext.Api.Features.Uploads.Presign;

public sealed class PresignUploadEndpoint(IAppCommandBus bus) : Endpoint<Request, Response>
{
    public override void Configure()
    {
        // ENDPOINT: POST /api/v1/uploads/presign
        Post("/api/v1/uploads/presign");
        // AUTH: Policy uploads.create — policy name is project vocabulary (authorization-patterns)
        Policies("uploads.create");
        MaxRequestBodySize(2 * 1024);
    }
    public override async Task HandleAsync(Request req, CancellationToken ct)
    {
        // IDEMPOTENCY: header read here, forwarded on the command — see api-endpoint-patterns §6
        var idem = HttpContext.Request.Headers.TryGetValue("Idempotency-Key", out var v) ? v.ToString() : null;
        var result = await bus.Send(
            new RequestPresignedUploadCommand(req.Filename, req.ContentType, req.SizeBytes, req.TargetVisibility, idem), ct);
        await this.ToHttpResultAsync(result, r => new Response(r.UploadId, r.PresignedUrl, r.FormFields, r.ExpiresAt), ct);
    }
}
public sealed record Request(string Filename, string ContentType, long SizeBytes, string TargetVisibility);
public sealed record Response(Guid UploadId, string PresignedUrl, IDictionary<string, string> FormFields, DateTimeOffset ExpiresAt);
```

The aggregate is created in `Pending` state by the handler. It transitions to `Quarantined` only when the client calls `POST /api/v1/uploads/{uploadId}/complete` — which dispatches `MarkUploadQuarantinedCommand` via `IAppCommandBus.Send` — confirming the bytes are uploaded.

## 7. Upload aggregate

Aggregate root in `YourContext.Domain.Uploads.Upload`. States: `Pending → Quarantined → Scanning → Clean → Processing → Available | Rejected`. State-mutating methods return `Result` for expected refusals and **raise domain events** for things that happened (`backend-feature-patterns §2`); they never throw for business failures.

```csharp
namespace YourContext.Domain.Uploads;

public sealed class Upload : AggregateRoot
{
    public UploadId Id { get; }
    public Guid OwnerId { get; } public Guid TenantId { get; }
    public UploadStatus Status { get; private set; }
    public string ContentType { get; private set; } public long SizeBytes { get; private set; }
    public string QuarantineKey { get; private set; } public string? FinalKey { get; private set; }
    public Bucket TargetBucket { get; private set; }
    public string? Checksum { get; private set; } public string? ScanSignature { get; private set; }

    public Result MarkQuarantined(string checksum)
    {
        if (Status != UploadStatus.Pending) return Error.Conflict("Upload.NotPending", "Upload is not pending");
        Status = UploadStatus.Quarantined; Checksum = checksum;  // UPLOAD-STATE: Pending → Quarantined
        RaiseEvent(new UploadQuarantinedEvent(Id.Value, OwnerId, TenantId, QuarantineKey, ContentType, TargetBucket));
        return Result.Success;
    }

    public Result MarkScanning()
    {
        if (Status != UploadStatus.Quarantined) return Error.Conflict("Upload.NotQuarantined", "Upload is not quarantined");
        Status = UploadStatus.Scanning;  // UPLOAD-STATE: Quarantined → Scanning
        return Result.Success;
    }

    public Result MarkClean()
    {
        if (Status != UploadStatus.Scanning) return Error.Conflict("Upload.NotScanning", "Upload is not scanning");
        Status = UploadStatus.Clean;  // UPLOAD-STATE: Scanning → Clean
        return Result.Success;
    }

    public Result MarkProcessing()
    {
        if (Status != UploadStatus.Clean) return Error.Conflict("Upload.NotClean", "Upload is not scan-clean");
        Status = UploadStatus.Processing;  // UPLOAD-STATE: Clean → Processing
        return Result.Success;
    }

    public Result MarkScanInfected(string sig)
    {
        Status = UploadStatus.Rejected; ScanSignature = sig;  // UPLOAD-STATE: → Rejected
        RaiseEvent(new UploadRejectedEvent(Id.Value, OwnerId, TenantId, sig));
        return Result.Success;
    }

    public Result MarkAvailable(string finalKey)
    {
        if (Status != UploadStatus.Processing) return Error.Conflict("Upload.NotProcessing", "Upload is not processing");
        Status = UploadStatus.Available; FinalKey = finalKey;  // UPLOAD-STATE: Processing → Available
        RaiseEvent(new UploadAvailableEvent(Id.Value, OwnerId, TenantId, TargetBucket, finalKey));
        return Result.Success;
    }
}
```

`UploadAvailableEvent` / `UploadRejectedEvent` are **domain** events; a `DomainEventHandler` promotes them to
integration events (`UploadAvailableIntegrationEvent`, etc.) by *returning* them — no bus reference
(`backend-feature-patterns §4`). Aggregate persistence + outbox-bound publish follow `data-access-patterns §3`.

```csharp
namespace YourContext.Application.DomainEventHandlers.Uploads;

public sealed class OnUploadAvailable
{
    // OUTBOX: returned integration event is written to the outbox in the command's transaction
    public IEnumerable<IIntegrationEvent> Handle(UploadAvailableEvent e)
    {
        yield return new UploadAvailableIntegrationEvent(e.UploadId, e.OwnerId, e.TenantId, e.TargetBucket, e.FinalKey); // lives in YourContext.Contracts
    }
}
```

## 8. UploadProcessingSaga

A saga is the right tool here: event-driven choreography, short-lived, no human wait (`orchestration-patterns §1`
decision rule). Its **authoring shape** — correlation, step guards, returning the next message(s) — follows
`orchestration-patterns`; its **runtime registration** (saga persistence, transaction + outbox binding) lives in
`infrastructure-wiring`. The saga is **not** a single transaction: each handler is its own transaction + outbox
commit. The saga holds **IDs in saga state** (`// SAGA-STATE:`), never live aggregate references; it loads the
aggregate through the repository when it needs to mutate it. Idempotent by saga state: re-receiving an event
whose step already ran is a no-op.

```csharp
namespace YourContext.Application.Files.Saga;

public sealed class UploadProcessingSaga : Saga
{
    public Guid Id { get; set; }                                              // SAGA-STATE: correlation
    public Guid UploadId { get; set; }                                        // SAGA-STATE: held by id, never an aggregate ref
    public Guid OwnerId { get; set; }                                         // SAGA-STATE
    public Guid TenantId { get; set; }                                        // SAGA-STATE
    public string QuarantineKey { get; set; } = "";                           // SAGA-STATE
    public string ContentType { get; set; } = "";                             // SAGA-STATE
    public Bucket TargetBucket { get; set; }                                  // SAGA-STATE
    public UploadStep Step { get; set; }                                      // SAGA-STATE

    // Step 1: Quarantined → scan. Loads bytes, scans, branches Clean | Infected.
    public async Task<object[]> Handle(UploadQuarantinedEvent evt, IFileStorageService storage, IVirusScanService scanner, CancellationToken ct)
    {
        if (Step >= UploadStep.Scanned) return [];
        Id = UploadId = evt.UploadId; OwnerId = evt.OwnerId; TenantId = evt.TenantId;
        QuarantineKey = evt.QuarantineKey; ContentType = evt.ContentType; TargetBucket = evt.TargetBucket;

        var opened = await storage.OpenReadAsync(Bucket.Quarantine, evt.QuarantineKey, ct);
        if (opened.IsError) throw new InvalidOperationException("Quarantine read failed — saga retry");
        await using var stream = opened.Value;

        var scan = await scanner.ScanAsync(stream, ct);
        if (scan.IsError) throw new InvalidOperationException("Scanner unavailable — saga retry");  // transient → retry
        Step = UploadStep.Scanned;
        return scan.Value.Outcome switch
        {
            ScanOutcome.Clean    => [new UploadScanCleanEvent(UploadId)],
            ScanOutcome.Infected => [new UploadScanInfectedEvent(UploadId, scan.Value.SignatureName ?? "unknown")],
            _                    => throw new InvalidOperationException("Scanner Error outcome — saga retry"),
        };
    }

    // Step 2: scan-clean → process (images only) and upload variants, then signal Processed.
    public async Task<object[]> Handle(UploadScanCleanEvent _, IImageProcessor images, IFileStorageService storage, CancellationToken ct)
    {
        if (Step >= UploadStep.Processed) return [];
        if (ContentType.StartsWith("image/"))
        {
            var opened = await storage.OpenReadAsync(Bucket.Quarantine, QuarantineKey, ct);
            if (opened.IsError) throw new InvalidOperationException("Quarantine read failed — saga retry");
            await using var src = opened.Value;

            var processed = await images.ProcessAsync(src, ImagePipelineDefaults.Options, ct);
            if (processed.IsError) throw new InvalidOperationException("Image processing failed — saga retry");

            // Variant upload via storage — each processed variant lands under the target bucket, keyed by variant name.
            foreach (var variant in processed.Value.Variants)
            {
                using var ms = new MemoryStream(variant.Bytes.ToArray());
                var variantKey = $"{TenantId}/{UploadId}/{variant.Name}.{variant.ContentType.Split('/')[^1]}";
                var put = await storage.PutAsync(TargetBucket, variantKey, ms, variant.ContentType, ct);
                if (put.IsError) throw new InvalidOperationException("Variant upload failed — saga retry");
            }
        }
        Step = UploadStep.Processed;
        return [new UploadProcessedEvent(UploadId)];
    }

    // Infected branch: purge quarantine, mark aggregate Rejected, end the saga.
    public async Task Handle(UploadScanInfectedEvent evt, IFileStorageService storage, IUploadsRepository repo, CancellationToken ct)
    {
        await storage.DeleteAsync(Bucket.Quarantine, QuarantineKey, ct);
        var loaded = await repo.GetByIdAsync(new UploadId(UploadId), ct);
        if (loaded.IsError) throw new InvalidOperationException("Upload not found — saga retry");
        loaded.Value.MarkScanInfected(evt.SignatureName);   // raises UploadRejectedEvent
        await repo.SaveChangesAsync(ct);                    // pipeline commits aggregate + outbox atomically
        MarkCompleted();
    }

    // Step 3: processed → promote to final bucket, mark Available, end the saga.
    public async Task Handle(UploadProcessedEvent _, IFileStorageService storage, IUploadsRepository repo, CancellationToken ct)
    {
        var finalKey = $"{TenantId}/{UploadId}/original";
        // BUCKET: quarantine → private|public — only reachable after scan-clean + process
        var moved = await storage.MoveAsync(Bucket.Quarantine, QuarantineKey, TargetBucket, finalKey, ct);
        if (moved.IsError) throw new InvalidOperationException("Promote move failed — saga retry");

        var loaded = await repo.GetByIdAsync(new UploadId(UploadId), ct);
        if (loaded.IsError) throw new InvalidOperationException("Upload not found — saga retry");
        loaded.Value.MarkAvailable(finalKey);   // raises UploadAvailableEvent → outbox via the DomainEventHandler (§7)
        await repo.SaveChangesAsync(ct);         // pipeline commits aggregate + outbox atomically
        MarkCompleted();
    }
}

public enum UploadStep { Started, Scanned, Processed, Done }
```

The infected and processed branches mutate the aggregate through `IUploadsRepository`; the command pipeline
behind the saga handler commits the aggregate write + the raised integration event atomically via the outbox
(`backend-architecture §6`) — the saga never publishes directly. Each handler is independently retryable on a
thrown infra exception (`orchestration-patterns`), and the `Step` guard makes re-delivery a no-op.

## 9. Adapter: SeaweedFS specifics

S3-compatible API via AWSSDK.S3 configured against the SeaweedFS endpoint. Adapter lives in `YourContext.Adapters.SeaweedFs`; app code never sees `IAmazonS3`. Client registration is `infrastructure-wiring`.

```csharp
namespace YourContext.Adapters.SeaweedFs;

// CONFIGUREAWAIT: adapter library code — see backend-architecture §7.
public sealed class SeaweedFileStorageService(IAmazonS3 s3, IOptions<SeaweedOptions> opts) : IFileStorageService
{
    public async Task<Result<UploadCredentials>> GetUploadCredentialsAsync(Bucket bucket, string key, TimeSpan ttl, CancellationToken ct)
    {
        var req = new GetPreSignedUrlRequest { BucketName = opts.Value.BucketName(bucket), Key = key, Verb = HttpVerb.PUT, Expires = DateTime.UtcNow.Add(ttl) };
        var url = await Task.Run(() => s3.GetPreSignedURL(req), ct).ConfigureAwait(false);
        return new UploadCredentials(url, new Dictionary<string, string>(), DateTimeOffset.UtcNow.Add(ttl));
    }
    // OpenReadAsync, MoveAsync (CopyObject + DeleteObject), PutAsync, DeleteAsync, GetSignedReadUrlAsync — analogous,
    // each returning Result/Result<T> and mapping S3 SDK exceptions to Error.Failure at the boundary.
}
```

Multi-part upload is used by the SDK transparently when files exceed ~100 MB.

## 10. Adapter: ImageSharp specifics

Configure at startup with format providers (JPEG, PNG, WebP, AVIF). Always strip EXIF before serving public images. Generate variants at upload time — never on read. Cache signed thumbnail URLs via the cache seam (TTL ≤ signed-URL-TTL / 2) — see `caching-patterns`.

```csharp
namespace YourContext.Adapters.ImageSharp;

// CONFIGUREAWAIT: adapter library code — see backend-architecture §7.
public sealed class ImageSharpProcessor : IImageProcessor
{
    public async Task<Result<ProcessedImage>> ProcessAsync(Stream source, ImageProcessingOptions options, CancellationToken ct)
    {
        using var img = await Image.LoadAsync(source, ct).ConfigureAwait(false);
        if (options.StripExif) img.Metadata.ExifProfile = null;
        var outs = new List<ProcessedImageVariant>(options.Variants.Count);
        foreach (var v in options.Variants)
        {
            using var clone = img.Clone(c => c.Resize(new ResizeOptions { Size = new Size(v.MaxWidth, v.MaxHeight), Mode = ResizeMode.Max }));
            await using var ms = new MemoryStream();
            IImageEncoder encoder = v.Format switch { "webp" => new WebpEncoder { Quality = v.Quality }, "jpeg" => new JpegEncoder { Quality = v.Quality }, _ => new PngEncoder() };
            await clone.SaveAsync(ms, encoder, ct).ConfigureAwait(false);
            outs.Add(new(v.Name, ms.ToArray(), $"image/{v.Format}", clone.Width, clone.Height));
        }
        return new ProcessedImage(outs);
    }
}
```

## 11. Adapter: nClam specifics

`ClamClient(host, port)` is connection-pooled per app instance. `PingAsync` health-checks on startup and via periodic probe — see `observability-backend` for health-probe wiring. The freshclam signature-update sidecar runs alongside the ClamAV daemon (deployment concern).

```csharp
namespace YourContext.Adapters.Nclam;

// CONFIGUREAWAIT: adapter library code — see backend-architecture §7.
public sealed class NclamVirusScanService(IOptions<NclamOptions> opts) : IVirusScanService
{
    public async Task<Result<ScanResult>> ScanAsync(Stream source, CancellationToken ct)
    {
        var client = new ClamClient(opts.Value.Host, opts.Value.Port) { MaxStreamSize = opts.Value.MaxBytes };
        var result = await client.SendAndScanFileAsync(source, ct).ConfigureAwait(false);
        return result.Result switch
        {
            ClamScanResults.Clean                  => new ScanResult(ScanOutcome.Clean),
            ClamScanResults.VirusDetected          => new ScanResult(ScanOutcome.Infected, result.InfectedFiles?.FirstOrDefault()?.VirusName),
            _                                      => Error.Failure("Scan.Unavailable", "Scanner returned an error outcome"),
        };
    }
}
```

## 12. Read path: serving files

Private files require an ABAC check (`authorization-patterns`) — the endpoint loads the `Upload` aggregate,
authorizes `CanReadUpload`, then issues a short-TTL signed URL via the storage port. Public files have no ABAC;
they are served via CDN with content-addressed keys.

```csharp
namespace YourContext.Api.Features.Uploads.GetUrl;

public sealed class GetUploadUrlEndpoint(IFileStorageService storage, IAuthorizationService authz, IUploadsReadService reads)
    : Endpoint<Request, Response>
{
    public override void Configure()
    {
        // ENDPOINT: GET /api/v1/uploads/{UploadId}/url
        Get("/api/v1/uploads/{UploadId}/url");
        // AUTH: Policy uploads.read — see authorization-patterns
        Policies("uploads.read");
    }
    public override async Task HandleAsync(Request req, CancellationToken ct)
    {
        var upload = await reads.GetByIdAsync(req.UploadId, ct);
        if (upload is null) { await this.ToHttpResultAsync<Response>(Error.NotFound("Upload.NotFound", "Upload not found"), ct); return; }
        // ABAC — only the owner may read a private upload (authorization-patterns)
        var ok = await authz.AuthorizeAsync(HttpContext.User, upload, "CanReadUpload");
        if (!ok.Succeeded) { await this.ToHttpResultAsync<Response>(Error.Forbidden("Upload.NoAccess", "Caller lacks access"), ct); return; }
        // BUCKET: private — owner-scoped signed URL, TTL ≤ 1h
        var url = await storage.GetSignedReadUrlAsync(Bucket.Private, upload.FinalKey!, TimeSpan.FromMinutes(15), ct);
        await this.ToHttpResultAsync(url, u => new Response(u, DateTimeOffset.UtcNow.AddMinutes(15)), ct);
    }
}
```

## 13. Cleanup, orphans, retention

- Orphan quarantine files (uploaded but never `complete`d): purged by a recurring job after 24h — see `orchestration-patterns` (`QuarantineCleanupJob`).
- Rejected uploads: deleted from quarantine immediately by the saga; aggregate retained for audit.
- Deleted aggregates: tombstone for 30d, then blob deletion in `private`/`public` via a recurring job.
- Physical-delete via bucket lifecycle policies OR via the cleanup job — never inline in a request handler.

## 14. Anti-patterns

- Raw S3 SDK / `IAmazonS3` injected into app code — use `IFileStorageService`.
- Raw `Image.Load` / `ImageSharp` API in app code — use `IImageProcessor`.
- Raw `ClamClient` in app code — use `IVirusScanService`.
- Injecting Wolverine `IMessageBus`/`IMessageContext` into an endpoint, handler, or saga, or putting `[Transactional]` on a handler — dispatch is `IAppCommandBus`/`IAppQueryBus`; the pipeline owns the transaction + outbox (NetArchTest invariant #1).
- Publishing an integration event directly from the saga — mutate the aggregate; raise a domain event; let the `DomainEventHandler` return the integration event (`backend-feature-patterns §4`).
- Reading + scanning + processing in a single handler — use the saga; each step is its own handler/transaction.
- Holding a live aggregate reference in saga state — hold the **id** and reload through the repository (§8).
- Serving from the `quarantine` bucket under any condition — always wait for scan-clean.
- Streaming uploads through the app process — use presigned URLs; client uploads direct to SeaweedFS.
- Storing EXIF in public images.
- Regenerating image variants on read — do it at upload time.
- Hardcoded bucket names in app code — use the `Bucket` enum.
- Signed-URL TTL > 1h for private files.
- Treating the saga as one transaction — it isn't; each handler is its own tx + outbox commit.

## 15. Comment markers emitted by this skill

- `// UPLOAD-STATE:` — annotates a state transition on the `Upload` aggregate.
- `// BUCKET:` — annotates a bucket choice (`quarantine` / `private` / `public`).

`// SAGA-STATE:` (saga correlation/state fields) is owned by `orchestration-patterns`; `// OUTBOX:` is the
outbox rule in `backend-architecture §6`. The canonical cross-skill marker index and the `// CONFIGUREAWAIT:`
rule live in `backend-architecture §7`.

## 16. Testing

Integration tests use `Testcontainers` for both SeaweedFS and ClamAV. The ClamAV container is seeded with the EICAR test signature so an infected-path test exercises the real scanner.

```csharp
[Fact]
public async Task Quarantined_clean_upload_reaches_Available()
{
    var uploadId = Guid.NewGuid();
    await fixture.UploadCleanBlobAsync(uploadId);
    await commandBus.Send(new MarkUploadQuarantinedCommand(uploadId, checksum: "abc"));
    await fixture.WaitForSagaCompleteAsync(uploadId, TimeSpan.FromSeconds(20));
    Assert.Equal(UploadStatus.Available, (await fixture.GetUploadAsync(uploadId)).Status);
}
```

See `orchestration-patterns` for the saga-test harness shape, and `backend-feature-patterns §12` for handler unit-test shape with fake repositories.

## 17. References

- `backend-architecture` — seams, structure, marker index, events model, invariants (read first).
- `backend-feature-patterns §2, §3, §4` — aggregate + handler shape, domain-event → integration-event flow.
- `orchestration-patterns` — saga decision rule + saga authoring shape; `QuarantineCleanupJob` lives here.
- `data-access-patterns §3` — `Upload` aggregate write repo + outbox binding.
- `api-endpoint-patterns §3, §6` — presigned endpoint dispatch + idempotency-key contract.
- `authorization-patterns` — RBAC policy `uploads.create`/`uploads.read` + ABAC `CanReadUpload`.
- `caching-patterns` — thumbnail / signed-URL caching.
- `integration-adapter-patterns` — scanner / storage adapter authoring with resilience.
- `infrastructure-wiring` — adapter client registration (SeaweedFS/ImageSharp/nClam) + saga runtime registration.
- `observability-backend` — health probes for ClamAV + SeaweedFS.
- `.specify/memory/system-context.md` — project bucket names + CDN config.
