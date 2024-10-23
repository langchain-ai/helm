#!/usr/bin/env python

import argparse
import requests
import sys
import sqlparse
import re
from sqlparse.sql import Identifier, IdentifierList
from sqlparse.tokens import Keyword

# Function to validate the clickhouse_url format
def validate_url(clickhouse_url):
    if not clickhouse_url.startswith("clickhouse://"):
        print("Error: Invalid clickhouse_url format.")
        print("Expected format: clickhouse://username:password@host:port/database")
        sys.exit(1)

# Function to parse the clickhouse_url into components
def parse_url(clickhouse_url):
    url_parts = clickhouse_url.split("://")[1].split("@")
    creds, host_part = url_parts[0], url_parts[1]
    host_parts = host_part.split("/")
    host, database = host_parts[0], host_parts[1]

    username, password = creds.split(":")
    host, port = host.split(":")

    return {
        "username": username,
        "password": password,
        "host": host,
        "port": port,
        "database": database
    }

# Unified function to make requests and handle responses
def make_request(url, data, error_code=None, error_substring=None):
    try:
        response = requests.post(url, data=data)
        # If an error code and substring are specified, handle them
        if response.status_code != 200:
            if error_code and error_substring:
                if response.status_code == error_code and error_substring in response.text:
                    return response  # Return the response without exiting
            print(f"Error Code: {response.status_code}, Message: {response.text.strip()}")
            sys.exit(1)
        return response
    except requests.exceptions.RequestException as e:
        print(f"Connection error: {str(e)}")
        sys.exit(1)

# Function to check if the is_deleted column exists in the target table
def check_is_deleted_column(url, database, table_name):
    query = f"SELECT count() FROM system.columns WHERE database = '{database}' AND table = '{table_name}' AND name = 'is_deleted'"
    response = make_request(url, query)
    return int(response.text.strip()) > 0

# Function to remove backslash escaping at ingest time
def clean_as_select(as_select):
    cleaned = as_select.replace("\\", "")
    return cleaned

def extract_column_aliases(as_select):
    parsed = sqlparse.parse(as_select)[0]
    columns = []
    
    for token in parsed.tokens:
        if token.ttype is Keyword and token.value.upper() == 'FROM':
            break  # Stop at the FROM clause
        if isinstance(token, IdentifierList):
            for identifier in token.get_identifiers():
                identifier_str = str(identifier)
                if ' AS ' in identifier_str:
                    alias = identifier_str.split(' AS ')[1].strip()
                    columns.append(alias)
                else:
                    columns.append(identifier_str.split('.')[-1].strip())
        elif isinstance(token, Identifier):
            identifier_str = str(token)
            if ' AS ' in identifier_str:
                alias = identifier_str.split(' AS ')[1].strip()
                columns.append(alias)
            else:
                columns.append(identifier_str.split('.')[-1].strip())

    return columns

# Function to extract the full expression for the SELECT clause (for proper escaping later)
def get_full_select(as_select):
    full_select = as_select.split("FROM")[0].replace("SELECT", "").strip()
    return full_select

# Function to add FINAL after the table name
def add_final_to_from_clause(from_clause, args):
    """Ensures that FINAL is added after the table name in the FROM clause."""
    # Log input for debugging
    if args.debug:
        print(f"add_final_to_from_clause input: {from_clause}")

    # Check if 'FINAL' is already in the clause
    if 'FINAL' in from_clause:
        if args.debug:
            print(f"add_final_to_from_clause output (no change): {from_clause}")
        return from_clause

    # Use regex to find the table name in the from_clause
    table_name_pattern = r'(\w+\.\w+)'

    # Search for the table name
    match = re.search(table_name_pattern, from_clause)
    if match:
        table_name = match.group(0)  # Extract the matched table name
        # Form the new from_clause with FINAL added after the table name
        new_from_clause = from_clause.replace(table_name, f"{table_name} FINAL")

        if args.debug:
            print(f"add_final_to_from_clause output: {new_from_clause}")

        return new_from_clause
    
    if args.debug:
        print(f"No valid table name found in from_clause: {from_clause}")

    return from_clause  # Return unchanged if no table name is found

def fetch_target_table_columns(base_url, database, target_table):
    """Fetches the columns of the target table."""
    query = f"SELECT name FROM system.columns WHERE database = '{database}' AND table = '{target_table}'"
    response = make_request(base_url, query)
    return response.text.strip().splitlines()

def append_missing_columns(select_columns, target_table_columns):
    """Identifies missing columns from the SELECT statement that are not in the target table."""
    return [col for col in select_columns if col not in target_table_columns and col != 'is_deleted']

def main():
    parser = argparse.ArgumentParser(description="Run queries on ClickHouse")
    parser.add_argument("clickhouse_url", help="ClickHouse URL in the format clickhouse://username:password@host:port/database")
    parser.add_argument("--ssl", action="store_true", help="Use SSL for the ClickHouse connection")
    parser.add_argument("--debug", action="store_true", help="Enable debug mode")
    parser.add_argument("--dryrun", action="store_true", help="Print queries without executing them")

    args = parser.parse_args()

    # Validate and parse the clickhouse URL
    validate_url(args.clickhouse_url)
    url_parts = parse_url(args.clickhouse_url)

    protocol = "https" if args.ssl else "http"
    base_url = f"{protocol}://{url_parts['host']}:{url_parts['port']}/?user={url_parts['username']}&password={url_parts['password']}"

    # Query to retrieve the target_table and as_select
    query = f"SELECT replaceAll(replaceAll(name,'_mv_v2','') ,'_mv','') AS target_table, as_select FROM system.tables WHERE name ILIKE '%mv%' AND database = '{url_parts['database']}' AND as_select != ''"

    # Retrieve the target_table and as_select
    response = make_request(base_url, query)
    result = response.text.strip().splitlines()

    for line in result:
        target_table, as_select = line.split("\t")

        if not target_table or not as_select:
            print("Error: Failed to parse target_table or as_select.")
            continue

        # Print the as_select for debugging
        if args.debug:
            print(f"as_select: {as_select}")

        # Clean the as_select SQL by removing any backslash escaping
        as_select = clean_as_select(as_select)

        # Extract the FROM clause
        try:
            from_clause = as_select.split("FROM")[1].strip()  # This should yield 'default.runs'
        except IndexError:
            print("Error: FROM clause not found in as_select.")
            continue
        
        # Add FINAL to the FROM clause
        from_clause_with_final = add_final_to_from_clause(from_clause, args)

        # Only print the final query in dry run mode
        if args.dryrun:
            # Get the final SELECT statement
            full_select = get_full_select(as_select)

            # Ensure the columns inside INSERT INTO match the order of the SELECT columns
            insert_columns = ", ".join(extract_column_aliases(as_select))
            # Use the original FROM clause with FINAL added
            final_query = f"INSERT INTO {target_table} ({insert_columns}) SELECT {full_select} FROM {from_clause_with_final} SETTINGS wait_for_async_insert=1"

            print(f"\nFinal Query:\n{final_query}")
            continue  # Skip the rest of the processing in dryrun mode

        # Detailed logging for debug mode
        if args.debug:
            print(f"\n--- Debug Mode ---")
            print(f"Returned target_table: {target_table}")
            print(f"Returned as_select query:\n{as_select}")
            print(f"Extracted from_clause: {from_clause}")

        # Further processing...
        select_columns = extract_column_aliases(as_select)
        if not select_columns and '*' in as_select:
            # If SELECT * is used, we need to fetch column names from the target table
            columns_query = f"SELECT name FROM system.columns WHERE database = '{url_parts['database']}' AND table = '{target_table}'"
            response = make_request(base_url, columns_query)
            select_columns = response.text.strip().splitlines()

        # Fetch columns from the target table
        target_table_columns = fetch_target_table_columns(base_url, url_parts['database'], target_table)

        # Check for missing columns
        missing_columns = append_missing_columns(select_columns, target_table_columns)

        # Prepare the final query
        if missing_columns:
            # Wrap the SELECT statement with EXCEPT for the missing columns
            select_excluded = ', '.join(missing_columns)
            inner_select = f"SELECT {', '.join(select_columns)} FROM {from_clause_with_final}"
            final_query = f"INSERT INTO {target_table} ({', '.join(select_columns)}) SELECT * EXCEPT ({select_excluded}) FROM ({inner_select}) SETTINGS wait_for_async_insert=1"
        else:
            # No missing columns, normal INSERT
            full_select = get_full_select(as_select)
            final_query = f"INSERT INTO {target_table} ({', '.join(select_columns)}) SELECT {full_select} FROM {from_clause_with_final} SETTINGS wait_for_async_insert=1"

        if args.dryrun:
            print(f"\nFinal Query:\n{final_query}")
        else:
            # Print before executing the query
            print(f"Executing INSERT INTO for {target_table}...")
            response = make_request(base_url, final_query, error_code=500, error_substring="Code: 181")
            if response.status_code == 500 and "Code: 181" in response.text:
                print("Received ILLEGAL_FINAL error. Retrying without FINAL...")

                # Remove FINAL from the query
                from_clause_without_final = from_clause_with_final.replace(" FINAL", "")
                final_query_without_final = f"INSERT INTO {target_table} ({', '.join(select_columns)}) SELECT {full_select} FROM {from_clause_without_final} SETTINGS wait_for_async_insert=1"
                
                # Print before executing the retry query
                print(f"Executing INSERT INTO for {target_table} without FINAL...")
                response = make_request(base_url, final_query_without_final)
            
            print(f"Successfully executed INSERT INTO for {target_table}.")

            # Print before running the OPTIMIZE query
            print(f"Optimizing table {target_table}...")
            optimize_query = f"OPTIMIZE TABLE {target_table} SETTINGS alter_sync = 2"
            response = make_request(base_url, optimize_query)
            print(f"Successfully optimized table {target_table}.")

if __name__ == "__main__":
    main()
