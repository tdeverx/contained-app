# Images

The Images area covers local image browsing, image actions, registry search,
updates, archives, and the experimental build workspace.

## Local images

Images are grouped by normalized reference and digest. When multiple runtimes are
available, the Images surface still shows one image group, while tag rows expose
where that tag exists locally. For example, Docker `nginx:latest` and Apple
container `nginx:latest` share registry/update metadata but remain separate
runtime-owned local tags.

Common actions:

- run image
- check for update
- pull available update
- tag
- push
- save archive
- load archive
- history
- prune

Tag/delete/save/push actions use the tag's owning runtime. Pull, build, and load
flows ask for a target runtime at the action surface unless they are launched
from an existing runtime-scoped tag or context.

## Docker Hub search

Docker Hub search is experimental and defaults off. Enable **Settings →
Experimental → Docker Hub search** to reveal registry search entry points in the
creation flow and command palette.

Search results can hand a selected image reference into the run configuration
flow.

## Image updates

Image update checks compare local and remote digests by normalized registry
reference or digest. Remote metadata is shared across runtimes; actual runnable
image availability remains owned by each runtime.

Manual checks are available from Images, System, the toolbar, and the command
palette. Background cadence is configured in [Updates](/Documentation/App/Updates.md).

## Build workspace

The image build workspace is experimental and defaults off. Enable **Settings →
Experimental → Image build workspace** to build from a Dockerfile and context
while streaming the BuildKit log.

The build path is entered through the shared [Creation Workflow](/Documentation/Features/Creation-Workflow.md).
