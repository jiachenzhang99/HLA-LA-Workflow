## WDL Compilation on UKB RAP

To compile this WDL workflow into an executable workflow on UKB RAP, use the dxCompiler tool:

```bash
java -jar dxCompiler-2.12.0.jar compile \
    hla_la_wf.wdl \
    -project [UKB Project ID] \
    -folder /UKB/directory/to/store/workflow
```
