## Overview

This file defines a composable set of Jenkins Job Builder (JJB) macros that
model the build parameters exposed by the Gerrit Trigger plugin. The intent is
to provide a faithful, structurally accurate representation of the parameters
that Jenkins receives for each Gerrit event type, while preserving the plugin’s
canonical naming and population semantics.

The model is derived from two authoritative sources:

1.  The [Gerrit Trigger plugin documentation], which enumerates the event
    families that Jenkins can receive and act upon.

2.  The [plugin implementation], which defines the canonical parameter names
    and the logic used to populate them at runtime. In particular:

    - `GerritTriggerParameters` enum constants
    - `GerritTriggerParameters#setOrCreateParameters(...)`
    - `GerritTriggerParameters#setOrCreateParametersForChangeBasedEvent(...)`

The parameter hierarchy below represents the union of fields documented by the
plugin and those declared and populated in the current implementation.

-------------------------------------------------------------------------------

## Gerrit Trigger Build Parameter Model

### Parameters Common to All Events

The following parameters are defined for every event type:

- `GERRIT_EVENT_TYPE`
- `GERRIT_EVENT_HASH`

When provider metadata is available, the plugin also sets:

- `GERRIT_NAME`
- `GERRIT_HOST`
- `GERRIT_PORT`
- `GERRIT_SCHEME`
- `GERRIT_VERSION`

If the event includes an `account` object, the event account identity is
exposed as:

- `GERRIT_EVENT_ACCOUNT_NAME`
- `GERRIT_EVENT_ACCOUNT_EMAIL`
- `GERRIT_EVENT_ACCOUNT_USERNAME`
- `GERRIT_EVENT_ACCOUNT`

These parameters form the invariant base layer for all event-driven builds.

-------------------------------------------------------------------------------

### Ref-Updated Events

For ref-updated events, the following additional parameters are defined:

- `GERRIT_PROJECT`
- `GERRIT_REFNAME`
- `GERRIT_OLDREV`
- `GERRIT_NEWREV`

These fields describe the repository, reference, and the revision delta that
triggered the event.

-------------------------------------------------------------------------------

### Change-Based Events

Change-based events share a common parameter structure, organized into core
change metadata, change owner identity, patch set data (when present), and
event-specific extensions.

#### Core Change Metadata

- `GERRIT_PROJECT`
- `GERRIT_BRANCH`
- `GERRIT_TOPIC`
- `GERRIT_CHANGE_NUMBER`
- `GERRIT_CHANGE_ID`
- `GERRIT_CHANGE_SUBJECT`
- `GERRIT_CHANGE_URL`
- `GERRIT_HASHTAGS`
- `GERRIT_CHANGE_WIP_STATE`
- `GERRIT_CHANGE_PRIVATE_STATE`

These parameters describe the logical change under review, independent of any
specific patch set.

#### Change Owner Identity

- `GERRIT_CHANGE_OWNER_NAME`
- `GERRIT_CHANGE_OWNER_EMAIL`
- `GERRIT_CHANGE_OWNER_USERNAME`
- `GERRIT_CHANGE_OWNER`

These fields reflect the identity of the change owner as provided in the event
payload.

#### Patch Set Data

When a patch set is associated with the event, the plugin exposes:

- `GERRIT_REFSPEC`
- `GERRIT_PATCHSET_REVISION`
- `GERRIT_PATCHSET_NUMBER`
- `GERRIT_PATCHSET_UPLOADER_NAME`
- `GERRIT_PATCHSET_UPLOADER_EMAIL`
- `GERRIT_PATCHSET_UPLOADER_USERNAME`
- `GERRIT_PATCHSET_UPLOADER`
- `GERRIT_CHANGE_COMMIT_MESSAGE`

These parameters capture the concrete revision under test, including uploader
identity and the full commit message.

#### Event-Specific Extensions

Certain change-based events introduce additional parameters:

- **comment-added**

  - `GERRIT_EVENT_COMMENT_TEXT`
  - `GERRIT_EVENT_UPDATED_APPROVALS`

- **change-abandoned**

  - `GERRIT_CHANGE_ABANDONER_NAME`
  - `GERRIT_CHANGE_ABANDONER_EMAIL`
  - `GERRIT_CHANGE_ABANDONER_USERNAME`
  - `GERRIT_CHANGE_ABANDONER`

- **change-restored**

  - `GERRIT_CHANGE_RESTORER_NAME`
  - `GERRIT_CHANGE_RESTORER_EMAIL`
  - `GERRIT_CHANGE_RESTORER_USERNAME`
  - `GERRIT_CHANGE_RESTORER`

- **topic-changed**

  - `GERRIT_OLD_TOPIC`
  - `GERRIT_TOPIC_CHANGER_NAME`
  - `GERRIT_TOPIC_CHANGER_EMAIL`
  - `GERRIT_TOPIC_CHANGER_USERNAME`
  - `GERRIT_TOPIC_CHANGER`

- **change-merged**

  - `GERRIT_NEWREV`

- **hashtags-changed**

  - `GERRIT_ADDED_HASHTAGS`
  - `GERRIT_REMOVED_HASHTAGS`

Each of these fields is conditionally populated based on the event type and the
presence of corresponding data in the Gerrit event payload.

-------------------------------------------------------------------------------

## Legacy Enum Fields

The plugin’s `GerritTriggerParameters` enum defines the following
submitter-related fields:

- `GERRIT_SUBMITTER_NAME`
- `GERRIT_SUBMITTER_EMAIL`
- `GERRIT_SUBMITTER_USERNAME`
- `GERRIT_SUBMITTER`

Although these constants remain declared, they are not populated by the current
`setOrCreateParameters(...)` execution path and therefore should be treated as
legacy or inactive in the present implementation.

-------------------------------------------------------------------------------

## JJB Macro Composition

The macros in this file are structured to reflect the plugin’s parameter
layering and to encourage reuse across event types.

### Ref-Updated Composition

- `tf-a-gerrit-ref-updated-parameters`
  - `tf-a-gerrit-parameters`
  - `tf-a-gerrit-ref-updated-core-parameters`

This composition layers common event parameters with the ref-updated core
fields.

### Change-Based Composition

For change-based events, the composition follows a deeper hierarchy:

- `tf-a-gerrit-<change-based-event>-parameters`
  - `tf-a-gerrit-change-based-patchset-parameters`
    - `tf-a-gerrit-change-based-parameters`
      - `tf-a-gerrit-parameters`
      - `tf-a-gerrit-change-core-parameters`
    - `tf-a-gerrit-patchset-core-parameters`
    - `tf-a-gerrit-commit-message-parameters`
  - `tf-a-gerrit-<event-specific-extras>-parameters` (where applicable)

This structure mirrors the runtime parameter population logic:

1.  Establish the common Gerrit event baseline.
2.  Add change-level metadata.
3.  Add patch set-specific data when available.
4.  Augment with event-specific extensions.

The result is a compositional model that aligns directly with the plugin’s
internal parameter construction flow, while remaining declarative and reusable
within JJB.

  [Gerrit Trigger plugin documentation]: https://plugins.jenkins.io/gerrit-trigger/
  [plugin implementation]: https://github.com/jenkinsci/gerrit-trigger-plugin/blob/master/src/main/java/com/sonyericsson/hudson/plugins/gerrit/trigger/hudsontrigger/GerritTriggerParameters.java
