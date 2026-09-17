---
name: ablation-experiment
description: Run ablation experiments to simplify code by removing mechanisms and checking whether required behavior still holds.
disable-model-invocation: true
---

# Ablation experiment

Establish a baseline, remove one mechanism at a time, and compare the same behavior checks and relevant measurements. Keep supported simplifications; revert unsuccessful experiments without disturbing the user's changes.

Do not weaken tests or remove safety and compatibility requirements to make an experiment pass. Report what was removed, the evidence, and any uncertainty.
