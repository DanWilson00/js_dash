#!/usr/bin/env python3
"""
MAVLink JSON Metadata Generator

Generates a JSON file containing all MAVLink message and enum metadata
for runtime consumption by the Flutter app. Leverages pymavlink for
XML parsing, include resolution, and CRC calculation.

Usage:
    python generator.py --input common.xml --output dialect.json
    python generator.py -i common.xml -o dialect.json
"""

import argparse
import json
import sys
import io
from datetime import datetime, timezone
from pathlib import Path


def parse_mavlink_xml_recursive(xml_path: str, parsed_files: set = None):
    """
    Parse MAVLink XML file using pymavlink, recursively resolving includes.

    Returns a tuple of (messages_dict, enums_dict) merged from all includes.
    """
    from pymavlink.generator.mavparse import MAVXML, message_checksum

    if parsed_files is None:
        parsed_files = set()

    xml_path = str(Path(xml_path).resolve())
    if xml_path in parsed_files:
        return {}, {}
    parsed_files.add(xml_path)

    # Suppress pymavlink warnings during parsing
    old_stdout = sys.stdout
    sys.stdout = io.StringIO()

    try:
        mav = MAVXML(xml_path, '2.0')
    finally:
        sys.stdout = old_stdout

    # Start with messages and enums from this file
    messages = {msg.id: msg for msg in mav.message}
    enums = {enum.name: enum for enum in mav.enum}

    # Recursively parse includes
    base_dir = Path(xml_path).parent
    for include_file in mav.include:
        include_path = base_dir / include_file
        if include_path.exists():
            inc_messages, inc_enums = parse_mavlink_xml_recursive(
                str(include_path), parsed_files
            )
            # Merge (child files take precedence for overrides)
            for msg_id, msg in inc_messages.items():
                if msg_id not in messages:
                    messages[msg_id] = msg
            for enum_name, enum in inc_enums.items():
                if enum_name not in enums:
                    enums[enum_name] = enum

    return messages, enums


def parse_mavlink_xml(xml_path: str):
    """
    Parse MAVLink XML file using pymavlink with full include resolution.

    Returns a pseudo-MAVXML-like object with message and enum lists.
    """
    messages_dict, enums_dict = parse_mavlink_xml_recursive(xml_path)

    # Create a simple namespace object to hold the results
    class MergedMAVXML:
        def __init__(self, messages, enums):
            self.message = list(messages.values())
            self.enum = list(enums.values())
            self.version = 3

    return MergedMAVXML(messages_dict, enums_dict)


def get_message_checksum(msg):
    """Calculate CRC extra for a message using pymavlink."""
    from pymavlink.generator.mavparse import message_checksum
    return message_checksum(msg)


def build_enum_json(enum) -> dict:
    """Convert a pymavlink MAVEnum to JSON-serializable dict."""
    entries = {}
    for entry in enum.entry:
        entries[str(entry.value)] = {
            "name": entry.name,
            "value": entry.value,
            "description": entry.description or "",
        }

    return {
        "name": enum.name,
        "description": enum.description or "",
        "bitmask": getattr(enum, 'bitmask', False),
        "entries": entries,
    }


def get_base_type(type_str: str) -> str:
    """Extract base type from MAVLink type string."""
    if type_str == 'uint8_t_mavlink_version':
        return 'uint8_t'
    if '[' in type_str:
        return type_str.split('[')[0]
    return type_str


def build_field_json(field) -> dict:
    """Convert a pymavlink MAVField to JSON-serializable dict."""
    base_type = get_base_type(field.type)

    # Calculate size in bytes
    type_sizes = {
        'int8_t': 1, 'uint8_t': 1, 'char': 1,
        'int16_t': 2, 'uint16_t': 2,
        'int32_t': 4, 'uint32_t': 4, 'float': 4,
        'int64_t': 8, 'uint64_t': 8, 'double': 8,
    }
    size = type_sizes.get(base_type, 1)

    return {
        "name": field.name,
        "type": field.type,
        "base_type": base_type,
        "offset": field.wire_offset,
        "size": size,
        "array_length": field.array_length if field.array_length else 1,
        "units": getattr(field, 'units', None),
        "enum": getattr(field, 'enum', None),
        "invalid": getattr(field, 'invalid', None),
        "display": getattr(field, 'display', None),
        "description": field.description or "",
        "extension": getattr(field, 'extension', False) if hasattr(field, 'extension') else False,
    }


def build_message_json(msg) -> dict:
    """Convert a pymavlink MAVType (message) to JSON-serializable dict."""
    crc_extra = get_message_checksum(msg)

    # Build fields list from ordered_fields
    fields = []
    for field in msg.ordered_fields:
        fields.append(build_field_json(field))

    return {
        "id": msg.id,
        "name": msg.name,
        "description": msg.description or "",
        "crc_extra": crc_extra,
        "encoded_length": msg.wire_length,
        "fields": fields,
    }


def generate_json(mav, dialect_name: str) -> dict:
    """Generate the complete JSON structure from parsed MAVLink."""
    # Build enums
    enums = {}
    for enum in mav.enum:
        enums[enum.name] = build_enum_json(enum)

    # Build messages
    messages = {}
    for msg in mav.message:
        messages[str(msg.id)] = build_message_json(msg)

    return {
        "schema_version": "1.0.0",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "dialect": {
            "name": dialect_name,
            "version": getattr(mav, 'version', 3),
        },
        "enums": enums,
        "messages": messages,
    }


def main():
    parser = argparse.ArgumentParser(
        description='Generate JSON metadata from MAVLink XML definitions'
    )
    parser.add_argument(
        '-i', '--input',
        required=True,
        help='Path to MAVLink XML file (e.g., common.xml)'
    )
    parser.add_argument(
        '-o', '--output',
        required=True,
        help='Output JSON file path'
    )
    parser.add_argument(
        '--pretty',
        action='store_true',
        help='Pretty-print JSON output'
    )

    args = parser.parse_args()

    # Validate input file
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file not found: {args.input}", file=sys.stderr)
        sys.exit(1)

    # Parse MAVLink XML
    print(f"Parsing {args.input}...")
    mav = parse_mavlink_xml(str(input_path))

    # Extract dialect name from filename
    dialect_name = input_path.stem

    # Generate JSON
    print(f"Generating JSON for {len(mav.message)} messages and {len(mav.enum)} enums...")
    json_data = generate_json(mav, dialect_name)

    # Write output
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    indent = 2 if args.pretty else None
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(json_data, f, indent=indent, ensure_ascii=False)

    print(f"Written to {args.output}")
    print(f"  Messages: {len(json_data['messages'])}")
    print(f"  Enums: {len(json_data['enums'])}")


if __name__ == '__main__':
    main()
