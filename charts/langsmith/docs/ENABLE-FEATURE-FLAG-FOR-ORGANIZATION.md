# Enable a feature flag for an organization

We have provided a script to enable a feature flag for a LangSmith organization. The script is located in the `scripts` directory of this repository.
### Prerequisites

Ensure you have the following tools/items ready.

1. PostgreSQL client
    1. https://www.postgresql.org/download/
2. PostgreSQL database connection:
    1. Host
    2. Port
    3. Username
       1. If using the bundled version, this is `postgres`
    4. Password
       1. If using the bundled version, this is `postgres`
    5. Database name
       1. If using the bundled version, this is `postgres` 
3. Connectivity to the PostgreSQL database from the machine you will be running the migration script on.
   1. If you are not using the bundled version in the image, you may need to port forward the postgresql service to your local machine.
   2. Run `kubectl port-forward svc/langsmith-postgres 5432:5432` to port forward the postgresql service to your local machine.
4. The name of the feature flag you want to add.
5. The id of the organization you want to add the feature flag to.

### Running the script

Run the following command to run feature flag script

```bash
sh enable_feature_flag_for_organization.sh <postgres connection url> <organization id> <feature flag name>
```

For example, if you are using the script directly with port-forwarding, the command would look like:

```bash
sh enable_feature_flag_for_organization.sh "postgres://postgres:postgres@localhost:5432/postgres" "6a389372-6e79-5cd0-bf66-d70249fb676e" "conversation_view_enabled"   
```

If you visit the Langsmith UI, you should now see the feature flag enabled.
