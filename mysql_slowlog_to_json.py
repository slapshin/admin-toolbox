#!/usr/bin/env python3
"""
MySQL Slow Query Log to NDJSON Converter

Parses MySQL slow query log files and converts them to NDJSON format.
NDJSON (Newline Delimited JSON) outputs one JSON object per line.
Supports standard MySQL slow log format with Time, User, Host, Query_time, etc.
"""

import json
import re
import sys
from datetime import datetime
from typing import Any, Dict, List


class SlowLogParser:
    def __init__(self):
        self.queries = []
        self.current_query = {}

    def parse_file(self, filepath: str) -> List[Dict]:
        """Parse a MySQL slow query log file."""
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                self._parse_line(line)

        # Add last query if exists
        if self.current_query and "sql" in self.current_query:
            self.queries.append(self.current_query)

        return self.queries

    def _parse_line(self, line: str):
        """Parse a single line from the slow log."""
        line = line.rstrip()

        # Skip empty lines
        if not line:
            return

        # Time line: # Time: 2023-11-07T10:30:45.123456Z
        if line.startswith("# Time:"):
            # Save previous query if exists
            if self.current_query and "sql" in self.current_query:
                self.queries.append(self.current_query)

            self.current_query = {}
            time_str = line.split("Time:", 1)[1].strip()
            self.current_query["timestamp"] = time_str

        # User@Host line
        elif line.startswith("# User@Host:"):
            pattern = r"(\S+)\[(\S+)\]\s+@\s+(\S+)\s+\[([\d.]*)\]"
            match = re.search(pattern, line)
            if match:
                self.current_query["user"] = match.group(1)
                self.current_query["database_user"] = match.group(2)
                self.current_query["host"] = match.group(3)
                ip = match.group(4) if match.group(4) else None
                self.current_query["ip"] = ip

        # Query_time line
        elif line.startswith("# Query_time:"):
            # Query_time: 2.123456  Lock_time: 0.000012
            # Rows_sent: 100  Rows_examined: 5000
            parts = line.split()
            for i, part in enumerate(parts):
                if part == "Query_time:" and i + 1 < len(parts):
                    self.current_query["query_time"] = float(parts[i + 1])
                elif part == "Lock_time:" and i + 1 < len(parts):
                    self.current_query["lock_time"] = float(parts[i + 1])
                elif part == "Rows_sent:" and i + 1 < len(parts):
                    self.current_query["rows_sent"] = int(parts[i + 1])
                elif part == "Rows_examined:" and i + 1 < len(parts):
                    self.current_query["rows_examined"] = int(parts[i + 1])

        # SET timestamp line
        elif line.startswith("SET timestamp="):
            match = re.search(r"SET timestamp=(\d+)", line)
            if match:
                timestamp = int(match.group(1))
                self.current_query["unix_timestamp"] = timestamp
                dt = datetime.fromtimestamp(timestamp).isoformat()
                self.current_query["datetime"] = dt

        # USE database line
        elif line.startswith("use "):
            db_name = line.split("use ", 1)[1].rstrip(";").strip()
            self.current_query["database"] = db_name

        # SQL query (not a comment line)
        elif not line.startswith("#"):
            # Append to SQL query
            if "sql" in self.current_query:
                self.current_query["sql"] += " " + line
            else:
                self.current_query["sql"] = line

    def parse_stdin(self) -> List[Dict]:
        """Parse MySQL slow query log from stdin."""
        for line in sys.stdin:
            self._parse_line(line)

        # Add last query if exists
        if self.current_query and "sql" in self.current_query:
            self.queries.append(self.current_query)

        return self.queries


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Convert MySQL slow query log to NDJSON format",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Parse a slow log file (outputs NDJSON by default)
  %(prog)s slow-query.log
  
  # Parse from stdin
  cat slow-query.log | %(prog)s
  
  # Pretty print as JSON array (disables NDJSON)
  %(prog)s slow-query.log --pretty
  
  # Filter queries slower than 5 seconds
  %(prog)s slow-query.log --min-time 5.0
  
  # Save to output file
  %(prog)s slow-query.log -o output.ndjson
        """,
    )

    parser.add_argument(
        "logfile",
        nargs="?",
        help="MySQL slow query log file (use stdin if not provided)",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output NDJSON file (default: stdout)",
    )
    parser.add_argument(
        "-p",
        "--pretty",
        action="store_true",
        help="Pretty print as JSON array (disables NDJSON format)",
    )
    parser.add_argument(
        "--min-time",
        type=float,
        help="Filter queries with query_time >= min-time",
    )
    parser.add_argument(
        "--min-rows",
        type=int,
        help="Filter queries with rows_examined >= min-rows",
    )

    args = parser.parse_args()

    # Parse the log
    slow_log = SlowLogParser()

    if args.logfile:
        queries = slow_log.parse_file(args.logfile)
    else:
        queries = slow_log.parse_stdin()

    # Apply filters
    if args.min_time is not None:
        queries = [q for q in queries if q.get("query_time", 0) >= args.min_time]

    if args.min_rows is not None:
        queries = [q for q in queries if q.get("rows_examined", 0) >= args.min_rows]

    # Write output
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            if args.pretty:
                # Pretty print as JSON array
                json.dump(queries, f, indent=2, ensure_ascii=False)
            else:
                # Output as NDJSON (one JSON object per line)
                for query in queries:
                    f.write(json.dumps(query, ensure_ascii=False))
                    f.write("\n")
        msg = f"Converted {len(queries)} queries to {args.output}"
        print(msg, file=sys.stderr)
    else:
        if args.pretty:
            # Pretty print as JSON array to stdout
            print(json.dumps(queries, indent=2, ensure_ascii=False))
        else:
            # Output as NDJSON (one JSON object per line)
            for query in queries:
                print(json.dumps(query, ensure_ascii=False))


if __name__ == "__main__":
    main()
