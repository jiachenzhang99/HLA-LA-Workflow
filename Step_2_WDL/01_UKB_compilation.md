## WDL Compilation on UKB RAP

To compile this WDL workflow into an executable workflow on UKB RAP, use the dxCompiler tool:

```bash
java -jar dxCompiler-2.12.0.jar compile \
    hla_la_wf.wdl \
    -project [UKB Project ID] \
    -folder /UKB/directory/to/store/workflow
```

### Prerequisties

- **dxCompiler**: Download the latest version from the dxWDL releases (https://documentation.dnanexus.com/downloads#dxcompiler)
- **dx CLI**: Ensure you have the DNAnexus command line tools installed and authenticated (https://documentation.dnanexus.com/downloads)
