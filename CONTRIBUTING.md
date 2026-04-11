# Contributing to BDB Genomics

Thank you for considering contributing to BDB Genomics! Your help makes open-source bioinformatics more powerful and robust.

Our goal is to build the most rigorous, modular standard for epigenomic and transcriptomic data processing. We welcome all contributions, whether you are fixing a bug, adding a new utility, or improving documentation.

---

## How Can I Help?

### 1. Reporting Bugs & Suggestions
If you find a bug or have a feature idea:
- Check if an **Issue** already exists.
- - If not, open a new one with details (logs, config, and example data).
 
  - ### 2. Submitting Pull Requests (PRs)
  - To contribute code:
  - - **Fork** the repository and create a branch from `main`.
    - - **Develop** your isolated Snakemake rule (`.smk`) and its environment (`.yaml`).
      - - **Use Conda**: Ensure rules rely strictly on isolated environment descriptors.
        - - **Test**: Confirm your changes pass the `validate_config.py` check.
          - - **Open a PR**: Describe your changes and any new parameters clearly.
           
            - ### 3. Improving Documentation
            - Bioinformatics is complex. If our guides are unclear or if you have a tutorial to share, please submit a documentation PR.
           
            - ---

            ## Architecture Guidelines
            - **Modularity**: Every tool must have its own `.smk` file and `.yaml` environment.
            - - **Fail Fast**: Build in checks to ensure the pipeline fails safely if inputs are flawed.
              - - **Parametrize**: Keep paths and variables in `config.yaml`, not in the rules.
               
                - *Thank you for helping us build better science.*
