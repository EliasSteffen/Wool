import json
import os
import sys

def main():
    # Path to the base version.json
    base_json_path = "version.json"

    # Check if base file exists
    if not os.path.exists(base_json_path):
        print(f"Error: {base_json_path} not found.")
        sys.exit(1)

    with open(base_json_path, 'r') as f:
        data = json.load(f)

    # Dictionary to map build folders to JSON keys
    # Key: folder name in build/, Value: key in "build_status"
    build_map = {
        "web": "web",
        "android": "android",
        "windows": "windows",
        "linux": "linux",
        "macos": "macos",
        "ios": "ios"
    }

    # Iterate through expected builds and check for success markers
    for folder, key in build_map.items():
        # Check if the build folder exists
        build_dir = os.path.join("build", folder)

        status = "pending" # Default if not found

        if os.path.exists(build_dir):
            if os.path.exists(os.path.join(build_dir, "success")):
                 status = "success"
            elif os.path.exists(os.path.join(build_dir, "failure")):
                 status = "failed"
            else:
                 status = "unknown"
        else:
            status = "skipped"

        # Update JSON
        if "build_status" not in data:
            data["build_status"] = {}

        data["build_status"][key] = status
        print(f"Build {key}: {status}")

    # Output to public folder (for GitLab Pages)
    output_dir = "public"
    os.makedirs(output_dir, exist_ok=True)

    output_path = os.path.join(output_dir, "version.json")
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=4)

    print(f"Updated version.json written to {output_path}")

if __name__ == "__main__":
    main()
