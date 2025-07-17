#! /bin/bash

declare -A latest_images
latest_images[csi-attacher]="$1"
latest_images[csi-provisioner]="$2"
latest_images[csi-snapshotter]="$3"
latest_images[csi-resizer]="$4"
latest_images[csi-node-driver-registrar]="$5"
latest_images[csi-external-health-monitor-controller]="$6"
latest_images[otel-collector]="$7"

# Global variables
updated_shortcodes=""
updated_installation_wizard=""

update_shortcodes() {
    for key in "${!latest_images[@]}"; do
        path="layouts/shortcodes/version-docs.html"
        name=$(echo $key | tr '-' '_')
        version=${latest_images[$key]}

        old_shortcode=$(grep -r "\"$name.*\" -}}" $path)

        # If no shortcode was found, we don't need to update it
        if [ -z "$old_shortcode" ]; then
            continue
        fi

        # If shortcode already contains the version, we don't need to update it
        if [[ "$old_shortcode" == *"$version"* ]]; then
            continue
        fi

        new_shortcode=$(echo $old_shortcode | sed "s/}}.*/}}$version/")

        updated_shortcodes+="\t$key to $version\n"
        sed -i "s|${old_shortcode}|${new_shortcode}|g" $path
    done
}

update_installation_wizard_sidecars() {
    # Sanitize the CSM version
    csm_version=$(echo $csm | tr -d 'v' | tr -d '\r')

    # The installation wizard templates should have the latest version of the CSM.
    wizard_files=$(find content/docs/getting-started/installation/installationwizard/src/templates/ -name "*$csm_version*")

    if [ -z "$wizard_files" ]; then
        echo "No Installation Wizard content for latest CSM found. Skipping."
        return
    fi

    for file in $wizard_files; do
        updated_images=""
        for key in "${!latest_images[@]}"; do
            # Retrieve the current version from the file of the sidecar.
            old_version=$(grep -r -m 1 "$key:" $file | xargs)
            if [ -z "$old_version" ]; then
                continue
            fi

            # All instance of the image in a file either go "image:/value:" so we remove that to get the pure image.
            old_version=$(echo $old_version | cut -d':' -f2- | tr -d ' ')
            new_version=$(echo $old_version | sed "s/:.*/:${latest_images[$key]}/")

            # If the version is the same, then we skip
            if [ "$old_version" == "$new_version" ]; then
                continue
            fi

            updated_images+="\t$new_version\n"

            # Update the version in the file.
            sed -i "s|${old_version}|${new_version}|g" $file
        done

        if [ -z "$updated_images" ]; then
            continue
        fi

        updated_installation_wizard+="Updated $file with the following images:\n$updated_images\n"
    done
}

handle_results() {
    if [ -z "$updated_shortcodes" ] && [ -z "$updated_installation_wizard" ]; then
        echo "No changes were made. Skipping."
        return
    fi

    if [ -n "$updated_shortcodes" ]; then
        echo -e "Updated Shortcodes:\n$updated_shortcodes"
    fi

    if [ -n "$updated_installation_wizard" ]; then
        echo -e "$updated_installation_wizard"
    fi
}

update_shortcodes_sidecars
update_installation_wizard_sidecars
handle_results
