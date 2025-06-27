#!/bin/bash
# This script will read the config.json and convert the p4 depots and branches to git

# if the clones directory does not exist, create it
if [ ! -d "bare-clones" ]; then
    echo "Creating bare-clones directory..."
    mkdir bare-clones
fi

if [ ! -d "clones" ]; then
    echo "Creating clones directory..."
    mkdir clones
fi

jq -c '.[]' config.json | while read -r depot; do
    DEPOT_PATH=$(echo "$depot" | jq -r '.depotPath')
    echo "Processing depot path: $DEPOT_PATH"

    # DEPOT_PATH is "//project/stuff/gl-exporter/..." or "//gl-exporter/...". Parse out the depot name before "/..."
    # Extract everything after the last "//" up to the last "/..."
    DEPOT_NAME=$(echo "$DEPOT_PATH" | sed -E 's|^//(.*/)*([^/]+)/\.\.\.$|\2|')
    echo "Depot name: $DEPOT_NAME"

    BRANCH_INCLUDE=""

    # Get all branches for this depot
    BRANCHES=$(echo "$depot" | jq -r '.branchConfig[].branch')
    
    # Build the BRANCH_INCLUDE string
    for branch_name in $BRANCHES; do
        echo "Processing branch: $branch_name for depot: $DEPOT_PATH"
        BRANCH_INCLUDE="$BRANCH_INCLUDE --branch $branch_name"
    done
    echo "Branch include options: $BRANCH_INCLUDE"

    # Run the p4-fusion command inside the Docker container
    docker run -u $(id -u):$(id -g) \
    -v $(pwd)/bare-clones:/p4-fusion/bare-clones \
    --mount type=bind,source="$P4TICKETS",target=/home/ubuntu/.p4tickets,readonly \
    --mount type=bind,source="$P4TRUST",target=/home/ubuntu/.p4trust,readonly \
    --mount type=bind,source="$P4ENVIRO",target=/home/ubuntu/.p4enviro,readonly \
    ghcr.io/robandpdx/p4-fusion:latest \
    /p4-fusion/build/p4-fusion/p4-fusion \
        --path $DEPOT_PATH \
        --user "$P4USER" \
        --port "$P4PORT" \
        --client "$P4CLIENT" \
        --src bare-clones/$DEPOT_NAME.git \
        --networkThreads $NETWORK_THREADS \
        --printBatch $PRINT_BATCH \
        --lookAhead $LOOKAHEAD \
        --retries $RETRIES \
        --refresh $REFRESH \
        --includeBinaries $INCLUDE_BINARIES \
        $BRANCH_INCLUDE

    # Create a clone from the bare clone
    cd clones
    git clone ../bare-clones/$DEPOT_NAME.git $DEPOT_NAME
    # make all the branches from the refs
    cd $DEPOT_NAME
    for REF in $(git for-each-ref --format='%(refname)' refs/remotes/origin/ | grep -v master | grep -v HEAD); do
        BRANCH_NAME=${REF#refs/remotes/origin/}
        git branch --track ${BRANCH_NAME} ${REF}
    done

    # LFS migrate large objects
    # The following extensions are included in the LFS migration:
    # png, jpg, jpeg, gif, tiff, bmp, psd, tga, exr, mp4, mov, avi, mkv, flv, webm, jar, exe
    git lfs migrate import --everything --include="*.[pP][nN][gG],*.[jJ][pP][gG],*.[jJ][pP][eE][gG],*.[gG][iI][fF],*.[tT][iI][fF][fF],*.[bB][mM][pP],*.[pP][sS][dD],*.[tT][gG][aA],*.[eE][xX][rR],*.[mM][pP]4,*.[mM][oO][vV],*.[aA][vV][iI],*.[mM][kK][vV],*.[fF][lL][vV],*.[wW][eE][bB][mM],*.[jJ][aA][rR],*.[eE][xX][eE]"
    git lfs migrate info --everything
    cd ..
    cd ..

done

