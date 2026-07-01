# Creation Workflow

The creation flow is the shared front door for creating and editing resources.
It avoids parallel sheets and keeps routing consistent across toolbar, sidebar,
menu, palette, empty-state, and card actions.

## Entry points

The flow can start from:

- run container
- edit container
- pull or search image
- configure a selected local or registry image
- import Compose
- create network
- create volume
- build image

## Presentation

With toolbar panel navigation enabled, run and edit open in the creation morph
from their measured toolbar origin. With it disabled, the same state opens
through classic pages or sheets so the sidebar fallback remains complete.

## Pages

Creation flow pages include:

- menu
- chooser
- search
- configure
- network
- volume
- build

The final container form is `ContainerConfigureView`, shared by new runs and
edits. See [[Run / Edit Form|Run-Edit-Form]].

## Feature gates

Some pages are experimental:

- Docker Hub search requires **Settings → Experimental → Docker Hub search**.
- Compose import requires **Settings → Experimental → Compose import**.
- Image build requires **Settings → Experimental → Image build workspace**.

Disabled gates hide or disable their matching entry points rather than leaving
dead buttons.
