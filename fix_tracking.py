import re

file_path = 'c:/Office Project/Trucks/truck-flutter/lib/features/rides/driver_tracking_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix driver name
content = re.sub(
    r"\(_bookingData\?\['driver'\]\?\['name'\] \?\? widget\.driverData\?\['booking'\]\?\['driver'\]\?\['name'\] \?\? widget\.driverData\?\['driver'\]\?\['name'\] \?\? 'Driver'\)\.toString\(\)",
    r"'${_bookingData?['driver']?['firstName'] ?? widget.driverData?['booking']?['driver']?['firstName'] ?? widget.driverData?['driver']?['firstName'] ?? ''} ${_bookingData?['driver']?['lastName'] ?? widget.driverData?['booking']?['driver']?['lastName'] ?? widget.driverData?['driver']?['lastName'] ?? ''}'.trim().isEmpty ? 'Driver' : '${_bookingData?['driver']?['firstName'] ?? widget.driverData?['booking']?['driver']?['firstName'] ?? widget.driverData?['driver']?['firstName'] ?? ''} ${_bookingData?['driver']?['lastName'] ?? widget.driverData?['booking']?['driver']?['lastName'] ?? widget.driverData?['driver']?['lastName'] ?? ''}'.trim()",
    content
)

# Fix vehicle assignment fallback
content = re.sub(
    r"final vehicle = _bookingData\?\['driver'\]\?\['vehicle'\] \?\?",
    r"final vehicle = _bookingData?['driver']?['assignedVehicle'] ?? _bookingData?['driver']?['vehicle'] ??",
    content
)

content = re.sub(
    r"widget\.driverData\?\['booking'\]\?\['driver'\]\?\['vehicle'\] \?\?",
    r"widget.driverData?['booking']?['driver']?['assignedVehicle'] ?? widget.driverData?['booking']?['driver']?['vehicle'] ??",
    content
)

content = re.sub(
    r"widget\.driverData\?\['driver'\]\?\['vehicle'\] \?\?",
    r"widget.driverData?['driver']?['assignedVehicle'] ?? widget.driverData?['driver']?['vehicle'] ??",
    content
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
