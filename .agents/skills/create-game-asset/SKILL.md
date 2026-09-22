# create-game-asset

## Purpose

Create production-oriented game assets through an agent workflow.

## Contract

Intent → Canonical Asset → States → Validation → Runtime Package

## Workflow

### 1. Intent Layer
Capture:
- asset purpose
- visual style
- target runtime
- required states

### 2. Canonical Asset Layer
Create one source of truth:
- character identity
- proportions
- palette
- material/style rules

### 3. State Layer
Expand canonical asset into states:
- idle
- movement
- action
- success
- failure
- special abilities

### 4. Validation Layer
Check:
- identity consistency
- pose correctness
- style consistency
- technical constraints

### 5. Runtime Layer
Package:
- sprites
- metadata
- animation states
- integration manifest

## Design Principle

Do not treat asset generation as:

Prompt → Image

Treat it as:

Intent → Entity → State Machine → Verified Artifact → Runtime Object
