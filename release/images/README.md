# Production workspace images

`zarf.yaml` owns the published production image pins. `local/zarf.yaml` carries
the same image repositories from local OCI archives. Both produce the same
mirror-only package interface; the root packaging recipes feed the corresponding
digests into template publication. Mirror before publishing changed references.

Update published pins here after image CI completes. Preserve old digests while
any template revision, package, release, or workspace references them.
