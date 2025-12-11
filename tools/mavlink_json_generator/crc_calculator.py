"""
MAVLink X.25 CRC Calculator

Implements the CRC calculation used by MAVLink for:
1. Packet validation (accumulating header + payload + crc_extra)
2. Message crc_extra calculation (for message identification)

IMPORTANT: CRC extra is calculated over ORDERED fields (sorted by type size,
largest first), NOT the original XML field order.
"""


def crc16_mcrf4xx(data: bytes, crc: int = 0xFFFF) -> int:
    """
    X.25 CRC calculation used by MAVLink.

    This is the MCRF4XX variant of CRC-16-CCITT.
    """
    for byte in data:
        tmp = byte ^ (crc & 0xFF)
        tmp = (tmp ^ (tmp << 4)) & 0xFF
        crc = ((crc >> 8) ^ (tmp << 8) ^ (tmp << 3) ^ (tmp >> 4)) & 0xFFFF
    return crc


def accumulate_byte(byte: int, crc: int = 0xFFFF) -> int:
    """Accumulate a single byte into CRC."""
    byte = byte & 0xFF
    tmp = byte ^ (crc & 0xFF)
    tmp = (tmp ^ (tmp << 4)) & 0xFF
    crc = ((crc >> 8) ^ (tmp << 8) ^ (tmp << 3) ^ (tmp >> 4)) & 0xFFFF
    return crc


def accumulate_string(s: str, crc: int = 0xFFFF) -> int:
    """Accumulate a string into CRC."""
    for char in s:
        crc = accumulate_byte(ord(char), crc)
    return crc


# MAVLink type sizes (in bits) for field ordering
TYPE_BITS = {
    'int8_t': 8,
    'uint8_t': 8,
    'char': 8,
    'int16_t': 16,
    'uint16_t': 16,
    'int32_t': 32,
    'uint32_t': 32,
    'float': 32,
    'int64_t': 64,
    'uint64_t': 64,
    'double': 64,
}


def get_base_type(type_str: str) -> str:
    """
    Extract base type from a MAVLink type string.

    Examples:
        'uint8_t' -> 'uint8_t'
        'uint8_t[20]' -> 'uint8_t'
        'uint8_t_mavlink_version' -> 'uint8_t'
    """
    # Handle special mavlink_version type
    if type_str == 'uint8_t_mavlink_version':
        return 'uint8_t'

    # Handle array types
    if '[' in type_str:
        return type_str.split('[')[0]

    return type_str


def get_array_length(type_str: str) -> int:
    """
    Extract array length from a MAVLink type string.

    Examples:
        'uint8_t' -> 1
        'uint8_t[20]' -> 20
        'float[4]' -> 4
    """
    if '[' in type_str:
        start = type_str.index('[') + 1
        end = type_str.index(']')
        return int(type_str[start:end])
    return 1


def get_type_bits(type_str: str) -> int:
    """Get the size in bits of a MAVLink type."""
    base_type = get_base_type(type_str)
    return TYPE_BITS.get(base_type, 8)


def get_type_size(type_str: str) -> int:
    """Get the size in bytes of a MAVLink type."""
    return get_type_bits(type_str) // 8


def order_fields_for_serialization(fields: list) -> list:
    """
    Order fields for serialization and CRC calculation.

    MAVLink orders fields as:
    1. Non-extension fields sorted by type size (largest first)
    2. Extension fields in original order
    """
    non_extension = [f for f in fields if not f.get('extension', False)]
    extension = [f for f in fields if f.get('extension', False)]

    # Sort non-extension fields by type size in bits (descending)
    non_extension.sort(key=lambda f: get_type_bits(f['type']), reverse=True)

    return non_extension + extension


def calculate_crc_extra(message_name: str, fields: list) -> int:
    """
    Calculate the CRC extra value for a MAVLink message.

    The CRC extra is calculated from:
    - Message name + space
    - For each non-extension field (in SIZE-ORDERED order, NOT XML order):
        - Base type (without array notation) + space
        - Field name + space
        - If array: array length byte

    Final CRC extra = (crc & 0xFF) ^ (crc >> 8)

    Args:
        message_name: The message name (e.g., 'HEARTBEAT')
        fields: List of dicts with 'name', 'type', and 'extension' keys
                Fields can be in any order - they will be reordered by size

    Returns:
        The CRC extra value (0-255)
    """
    crc = 0xFFFF

    # Accumulate message name + space
    crc = accumulate_string(message_name + ' ', crc)

    # Order fields by size (largest first) - this is critical!
    ordered_fields = order_fields_for_serialization(fields)

    # Accumulate each non-extension field
    for field in ordered_fields:
        if field.get('extension', False):
            continue

        # Get base type (strip array notation and handle special types)
        base_type = get_base_type(field['type'])

        # Accumulate type + space
        crc = accumulate_string(base_type + ' ', crc)

        # Accumulate name + space
        crc = accumulate_string(field['name'] + ' ', crc)

        # If array, accumulate array length
        array_length = get_array_length(field['type'])
        if array_length > 1:
            crc = accumulate_byte(array_length, crc)

    # Final CRC extra calculation
    return (crc & 0xFF) ^ (crc >> 8)


def calculate_field_offsets(fields: list) -> list:
    """
    Calculate byte offsets for each field after reordering.

    Returns a new list with 'offset' and 'size' added to each field.
    """
    ordered = order_fields_for_serialization(fields)
    offset = 0

    result = []
    for field in ordered:
        base_type = get_base_type(field['type'])
        size = get_type_size(field['type'])
        array_length = get_array_length(field['type'])

        new_field = dict(field)
        new_field['offset'] = offset
        new_field['size'] = size
        new_field['array_length'] = array_length
        new_field['base_type'] = base_type

        result.append(new_field)
        offset += size * array_length

    return result


if __name__ == '__main__':
    # Test with HEARTBEAT message
    # Fields in XML order (will be reordered by size)
    heartbeat_fields = [
        {'name': 'type', 'type': 'uint8_t', 'extension': False},
        {'name': 'autopilot', 'type': 'uint8_t', 'extension': False},
        {'name': 'base_mode', 'type': 'uint8_t', 'extension': False},
        {'name': 'custom_mode', 'type': 'uint32_t', 'extension': False},
        {'name': 'system_status', 'type': 'uint8_t', 'extension': False},
        {'name': 'mavlink_version', 'type': 'uint8_t_mavlink_version', 'extension': False},
    ]

    crc = calculate_crc_extra('HEARTBEAT', heartbeat_fields)
    print(f'HEARTBEAT CRC extra: {crc} (expected: 50)')

    # Show field ordering
    print('\nHEARTBEAT field ordering:')
    ordered = calculate_field_offsets(heartbeat_fields)
    for f in ordered:
        print(f"  offset={f['offset']:2d}: {f['name']} ({f['type']})")

    # Test with SYS_STATUS (id=1, expected crc_extra=124)
    sys_status_fields = [
        {'name': 'onboard_control_sensors_present', 'type': 'uint32_t', 'extension': False},
        {'name': 'onboard_control_sensors_enabled', 'type': 'uint32_t', 'extension': False},
        {'name': 'onboard_control_sensors_health', 'type': 'uint32_t', 'extension': False},
        {'name': 'load', 'type': 'uint16_t', 'extension': False},
        {'name': 'voltage_battery', 'type': 'uint16_t', 'extension': False},
        {'name': 'current_battery', 'type': 'int16_t', 'extension': False},
        {'name': 'battery_remaining', 'type': 'int8_t', 'extension': False},
        {'name': 'drop_rate_comm', 'type': 'uint16_t', 'extension': False},
        {'name': 'errors_comm', 'type': 'uint16_t', 'extension': False},
        {'name': 'errors_count1', 'type': 'uint16_t', 'extension': False},
        {'name': 'errors_count2', 'type': 'uint16_t', 'extension': False},
        {'name': 'errors_count3', 'type': 'uint16_t', 'extension': False},
        {'name': 'errors_count4', 'type': 'uint16_t', 'extension': False},
        # Extension fields (not included in CRC)
        {'name': 'onboard_control_sensors_present_extended', 'type': 'uint32_t', 'extension': True},
        {'name': 'onboard_control_sensors_enabled_extended', 'type': 'uint32_t', 'extension': True},
        {'name': 'onboard_control_sensors_health_extended', 'type': 'uint32_t', 'extension': True},
    ]

    crc = calculate_crc_extra('SYS_STATUS', sys_status_fields)
    print(f'\nSYS_STATUS CRC extra: {crc} (expected: 124)')

    # Test ATTITUDE (id=30)
    attitude_fields = [
        {'name': 'time_boot_ms', 'type': 'uint32_t', 'extension': False},
        {'name': 'roll', 'type': 'float', 'extension': False},
        {'name': 'pitch', 'type': 'float', 'extension': False},
        {'name': 'yaw', 'type': 'float', 'extension': False},
        {'name': 'rollspeed', 'type': 'float', 'extension': False},
        {'name': 'pitchspeed', 'type': 'float', 'extension': False},
        {'name': 'yawspeed', 'type': 'float', 'extension': False},
    ]

    crc = calculate_crc_extra('ATTITUDE', attitude_fields)
    print(f'ATTITUDE CRC extra: {crc} (expected: 39)')
