---
name: openscad
description: Create, validate, preview, parameterize, and export OpenSCAD models for 3D printing.
metadata:
  source: "https://github.com/mitsuhiko/agent-stuff"
  commit: "13bc8f87970bec8830aab0f1c0487d35aa7c0917"
---

Use this skill for OpenSCAD models. OpenSCAD must be available on `PATH`; if it is missing, ask the user to add it through system configuration rather than installing it imperatively.

```bash
bash tools/validate.sh model.scad
bash tools/multi-preview.sh model.scad previews/
bash tools/extract-params.sh model.scad --json
bash tools/export-stl.sh model.scad model.stl -D 'width=60'
```

After creating or modifying a model, validate syntax and generate multi-angle previews. Inspect every generated PNG before delivery: syntax checks do not catch incorrect proportions, booleans, floating geometry, or other visual defects. Use `bash tools/render-with-params.sh model.scad params.json output.stl` for JSON-defined parameters.
