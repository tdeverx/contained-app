# Images

The Images area covers local image browsing, image actions, registry search,
updates, archives, and the experimental build workspace.

## Local images

Images are grouped by reference and tag. Image group and tag styling can inherit
from app defaults or local overrides.

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

## Docker Hub search

Docker Hub search is experimental and defaults off. Enable **Settings →
Experimental → Docker Hub search** to reveal registry search entry points in the
creation flow and command palette.

Search results can hand a selected image reference into the run configuration
flow.

## Image updates

Image update checks compare local and remote digests. Status is stored locally so
cards, palette results, toolbar panels, and System can show whether an update is
available.

Manual checks are available from Images, System, the toolbar, and the command
palette. Background cadence is configured in [[Updates]].

## Build workspace

The image build workspace is experimental and defaults off. Enable **Settings →
Experimental → Image build workspace** to build from a Dockerfile and context
while streaming the BuildKit log.

The build path is entered through the shared [[Creation Workflow|Creation-Workflow]].
