### Runtime & Images

- Added Docker CLI runtime support in `ContainedCore`, with Docker command builders, decoders, create/Compose translation, runtime descriptors, CLI discovery, and a first-class adapter beside Apple `container`.
- Aggregated containers from reachable runtimes while routing lifecycle, logs, stats, terminal, files, edit, and health actions through each container's owning runtime.
- Unified Images at the group level while exposing runtime-specific local tag availability and actions for Apple container and Docker image stores.
- Added runtime-scoped settings sections and Docker CLI path overrides; Apple service, kernel, and DNS controls remain Apple-only, while Docker endpoint failures show retry/runtime guidance.
- Kept V1 image storage runtime-owned while centralizing registry search, remote digest/update metadata, and normalized tag grouping across runtimes.
- Removed implicit runtime fallbacks so create, pull, build, load, push, registry, network, volume, logs, stats, terminal, and migration actions route through an explicit runtime or an existing resource owner.
- Replaced alert-based runtime picking for no-context Compose/image archive imports with an in-app runtime selection sheet that preselects only when one compatible runtime is available.
- Moved migration visibility and runtime move progress into the app database/Core migration flow, retaining disappeared resources only when they carry Contained-owned value.
- Fixed the container-card morph regression by keying measured card frames and expanded overlays by runtime-scoped container IDs.
