# SRPS Config Deployment

**SRPS Targeted Config Deployments: Transaction Definition Dependency Export Flag Automation**

Tools and scripts for managing export flags in the SRPS (State Registration & Professional Services) entellitrak system.

## Overview

This repository contains utilities for setting export flags on transaction definitions and related configuration objects in the SRPS licensing system (ILDFPR implementation). Export flags control which objects are included when exporting entellitrak configuration bundles.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/brenanmartinez/srps-config-deployment.git
cd srps-config-deployment

# Run the export flag generator
./scripts/generate_export_flag_script.sh transaction_codes.txt > export_flags.sql

# Review the generated SQL
less export_flags.sql

# Apply to your environment (after review!)
sqlcmd -S your-server -d your-database -i export_flags.sql
```

## Repository Contents

- **[scripts/](scripts/)** - Shell scripts and utilities
  - `generate_export_flag_script.sh` - Main export flag SQL generator
  - `validate_transaction_codes.sh` - Transaction code format validator
  
- **[docs/](docs/)** - Documentation
  - `USAGE_GUIDE.md` - Detailed usage instructions
  - `GITHUB_INTEGRATION_PLAN.md` - Future GitHub Actions automation plan
  - `TRANSACTION_CODE_REFERENCE.md` - Common transaction codes

- **[examples/](examples/)** - Example files
  - Sample transaction code lists
  - Sample output SQL scripts

## What Are Export Flags?

Export flags (C_EXPORT column) are boolean flags in entellitrak configuration tables that determine which objects should be included in `.eab` bundle exports. Setting these flags correctly ensures:

- Only relevant transaction definitions are exported
- Related configuration (fees, rules, letter templates) is included
- Exports remain manageable and focused

## Key Features

- ✅ **Automated SQL generation** - No manual SQL writing
- ✅ **Dependency tracking** - Automatically includes related objects (fees, rules, etc.)
- ✅ **Validation** - Format checking for transaction codes
- ✅ **Transaction safety** - All operations wrapped in transactions
- ✅ **Reset capability** - Clears existing flags before setting new ones

## Target Tables

The generator updates export flags in:
- `T_PSO_TRANSACTION_DEFINITION` - Transaction definitions
- `T_PSO_FEE_DEFINITION` - Fee definitions
- `T_PSO_REVENUE_CODE` - Revenue codes
- `T_PSO_RULE_DEFINITION` - Business rules
- `T_PSO_LETTER_TEMPLATE` - Letter templates
- `T_PSO_RELATIONSHIP_DEFINITION` - Relationship definitions

## Future: GitHub Actions Integration

See [docs/GITHUB_INTEGRATION_PLAN.md](docs/GITHUB_INTEGRATION_PLAN.md) for the roadmap toward automated export flag execution via GitHub Actions workflows with full security controls.

## Contributing

This is an internal Tyler Technologies / ILDFPR project. For access or questions, contact the ILDFPR development team.

## Version

**Current Version**: 1.0  
**Last Updated**: 2026-06-10  
**Maintained By**: Brenan Martinez

## License

Internal use only - Tyler Technologies / State of Illinois IDFPR
