#!/bin/bash
# This script will read the config.json and convert the p4 depots and branches to git

# Exit immediately if any command exits with a non-zero status
# set -e

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
    GITHUB_REPO_NAME=$(echo "$depot" | jq -r '.githubRepoName')
    GITHUB_REPO_VISIBILITY=$(echo "$depot" | jq -r '.githubRepoVisibility')

    # DEPOT_PATH is "//project/stuff/gl-exporter/..." or "//gl-exporter/...". Parse out the depot name before "/..."
    # Extract everything after the last "//" up to the last "/..."
    DEPOT_NAME=$(echo "$DEPOT_PATH" | sed -E 's|^//(.*/)*([^/]+)/\.\.\.$|\2|')
    echo "Depot name: $DEPOT_NAME"

    BRANCH_INCLUDE=""

    # Get all branches for this depot
    BRANCHES=$(echo "$depot" | jq -r '.branchConfig[].branch')
    # get the first branch from the depot using jq
    MAIN_BRANCH=$(echo "$depot" | jq -r '.branchConfig[0].branch')

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

    # Checkout the main branch
    echo "Checking out main branch: $MAIN_BRANCH"
    git checkout $MAIN_BRANCH

    # Check if LFS is enabled for this depot
    LFS_ENABLED=$(echo "$depot" | jq -r '.lfs')
    if [ "$LFS_ENABLED" = "true" ]; then
        echo "LFS is enabled for this depot. Processing LFS migration..."
        
        # Get the lfsTrack extensions from config
        LFS_EXTENSIONS=$(echo "$depot" | jq -r '.lfsTrack[]')
        
        # Convert extensions to case-insensitive patterns
        LFS_PATTERNS=""
        for ext in $LFS_EXTENSIONS; do
            # Remove the leading *. if present
            ext_clean=$(echo "$ext" | sed 's/^\*\.//')
            
            # Convert each character to case-insensitive pattern
            pattern="*."
            for (( i=0; i<${#ext_clean}; i++ )); do
                char="${ext_clean:$i:1}"
                pattern="${pattern}[${char^^}${char,,}]"
            done
            
            if [ -z "$LFS_PATTERNS" ]; then
                LFS_PATTERNS="$pattern"
            else
                LFS_PATTERNS="$LFS_PATTERNS,$pattern"
            fi
        done
        
        echo "LFS patterns: $LFS_PATTERNS"
        
        # LFS migrate large objects
        git lfs migrate import --everything --include="$LFS_PATTERNS"
        git lfs migrate info --everything
    else
        echo "LFS is disabled for this depot. Skipping LFS migration."
    fi


    if [ -n "$GITHUB_REPO_NAME" ] && [ "$GITHUB_REPO_NAME" != "null" ]; then
        echo "Creating GitHub repository: $GITHUB_ORG/$GITHUB_REPO_NAME"
        # Create new repo in GitHub using gh cli
        gh repo create "$GITHUB_ORG/$GITHUB_REPO_NAME" --"$GITHUB_REPO_VISIBILITY"
        # Add github remote
        echo "Pushing to GitHub repository: $GITHUB_ORG/$GITHUB_REPO_NAME"
        git remote add github "https://github.com/$GITHUB_ORG/$GITHUB_REPO_NAME.git"
        # Push repo to GitHub
        git push --all github
    else
        echo "Skipping GitHub repository creation."
    fi
    
    cd ..
    cd ..

done

