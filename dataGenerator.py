import json
import random
from datetime import datetime, timedelta
import os

# Configuration
OUTPUT_FILE = "./src/data/mydata.json"
HOURS_OF_DATA = 24  # How many data points per device

# Define devices with their specific types/categories
DEVICES = [
    {"id": "METER-01", "type": "Smart Meter", "name": "Main Grid Meter"},
    {"id": "METER-02", "type": "Smart Meter", "name": "Solar Sub-meter"},
    {"id": "IOT-HEAT-01", "type": "HVAC System", "name": "Living Room Heater"},
    {"id": "IOT-COOL-01", "type": "HVAC System", "name": "Bedroom AC"},
    {"id": "EV-CHARGER-01", "type": "EV Charger", "name": "Garage Charger"}
]

def generate_data():
    print(f"Generating structured data for {len(DEVICES)} devices...")
    
    # Root structure changed from "included" to "devices"
    data = {
        "devices": [] 
    }

    # Start from 24 hours ago
    start_time = datetime.now().replace(minute=0, second=0, microsecond=0) - timedelta(hours=HOURS_OF_DATA)

    # 1. Loop through each device to create the containers
    for device in DEVICES:
        
        # Calculate a fake max capacity for percentage math
        max_power_capacity = 4000.0 # Watts
        
        device_entry = {
            "type": device["type"],
            "id": device["id"],
            "data": {   # Renamed from "attributes" to "data" to be similar but not equal
                "label": device["name"], # Renamed from "title"
                "readings": [] # Renamed from "values"
            }
        }

        # 2. Generate values specifically for THIS device
        for i in range(HOURS_OF_DATA):
            current_time = (start_time + timedelta(hours=i)).isoformat()
            
            # Simulate electrical readings
            voltage = round(random.uniform(220.0, 240.0), 2)
            current = round(random.uniform(0.5, 15.0), 2)
            power_w = round(voltage * current, 2)
            
            # Create the value record with FLATTENED fields (merged meta directly in)
            record = {
                "timestamp": current_time,               # Renamed from "datetime"
                "value": power_w,
                "percentage": round(power_w / max_power_capacity, 2),
                
                # Flattened fields (formerly nested in "meta")
                "voltage_v": voltage,
                "current_a": current,
                "temperature_c": round(random.uniform(20.0, 45.0), 1),
                "status": "active" if random.random() > 0.05 else "error"
            }
            
            device_entry["data"]["readings"].append(record)

        # Add the completed device block to the main list
        data["devices"].append(device_entry)

    # Ensure directory exists
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

    with open(OUTPUT_FILE, "w") as f:
        json.dump(data, f, indent=2)
    
    print(f"Success! Data saved to {OUTPUT_FILE}")

if __name__ == "__main__":
    generate_data()