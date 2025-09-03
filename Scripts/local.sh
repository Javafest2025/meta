#!/bin/bash

###############################################################################
# ScholarAI Meta Repository - Local Development Script
# Handles git operations for all submodules and main repository
###############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                 ScholarAI Meta Repository                    ║${NC}"
    echo -e "${PURPLE}║                   Git Operations Manager                     ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Help function
help() {
    print_header
    echo ""
    echo "Available Commands:"
    echo ""
    echo -e "  ${CYAN}./Scripts/local.sh pull-all${NC}     - Pull all submodules and main meta repo"
    echo -e "  ${CYAN}./Scripts/local.sh status${NC}       - Show status of all repositories"
    echo -e "  ${CYAN}./Scripts/local.sh push-all${NC}     - Push all submodules and main meta repo"
    echo -e "  ${CYAN}./Scripts/local.sh sync${NC}         - Sync all repositories (pull + push)"
    echo -e "  ${CYAN}./Scripts/local.sh check${NC}        - Check for uncommitted changes"
    echo -e "  ${CYAN}./Scripts/local.sh help${NC}         - Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  ./Scripts/local.sh pull-all    # Pull latest changes from all repos"
    echo "  ./Scripts/local.sh status      # Check status of all repositories"
    echo ""
}

# Get the root directory of the meta repository
get_meta_root() {
    # Get the directory containing this script
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # The meta root should be the parent directory of Scripts
    echo "$(dirname "$script_dir")"
}

# Pull all submodules and main meta repo
pull_all() {
    print_header
    print_info "Starting comprehensive pull operation..."
    
    local META_ROOT=$(get_meta_root)
    print_info "Meta repository root: $META_ROOT"
    cd "$META_ROOT"
    
    # Variables to track status
    local submodule_errors=0
    local main_repo_error=0
    local total_submodules=0
    local successful_submodules=0
    
    print_info "=========================================="
    print_info "PHASE 1: Pulling all submodules"
    print_info "=========================================="
    
    # Check if submodules exist
    if [[ ! -f ".gitmodules" ]]; then
        print_warning "No .gitmodules file found. Skipping submodule updates."
    else
        # Get total number of submodules
        total_submodules=$(git submodule status | wc -l)
        print_info "Found $total_submodules submodules to process..."
        echo ""
        
        # Use git submodule foreach to properly handle submodules
        git submodule foreach --recursive '
            submodule_name="$name"
            echo -e "\033[0;34m[INFO]\033[0m Processing submodule: $submodule_name"
            
            # Get current branch
            current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
            if [[ $? -ne 0 ]]; then
                echo -e "\033[0;31m[ERROR]\033[0m   ❌ Failed to get current branch for $submodule_name"
                exit 1
            fi
            
            echo -e "\033[0;34m[INFO]\033[0m   📍 Current branch: $current_branch"
            
            # Check for uncommitted changes
            if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                echo -e "\033[1;33m[WARNING]\033[0m   ⚠️  Uncommitted changes detected in $submodule_name"
                git status --porcelain
                echo -e "\033[1;33m[WARNING]\033[0m   🔄 Stashing changes before pull..."
                git stash push -m "Auto-stash before pull-all at $(date)" >/dev/null 2>&1
            fi
            
            # Fetch first
            echo -e "\033[0;34m[INFO]\033[0m   🔄 Fetching from origin..."
            if ! git fetch origin >/dev/null 2>&1; then
                echo -e "\033[0;31m[ERROR]\033[0m   ❌ Failed to fetch from origin for $submodule_name"
                exit 1
            fi
            
            # Check if remote branch exists
            if ! git ls-remote --exit-code --heads origin "$current_branch" >/dev/null 2>&1; then
                echo -e "\033[1;33m[WARNING]\033[0m   ⚠️  Remote branch $current_branch does not exist, trying main..."
                if git ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
                    current_branch="main"
                elif git ls-remote --exit-code --heads origin master >/dev/null 2>&1; then
                    current_branch="master"
                else
                    echo -e "\033[0;31m[ERROR]\033[0m   ❌ No suitable remote branch found for $submodule_name"
                    exit 1
                fi
            fi
            
            # Try to pull
            echo -e "\033[0;34m[INFO]\033[0m   🔄 Pulling $current_branch..."
            if git pull origin "$current_branch" >/dev/null 2>&1; then
                echo -e "\033[0;32m[SUCCESS]\033[0m   ✅ Successfully pulled $submodule_name"
                exit 0
            else
                echo -e "\033[0;31m[ERROR]\033[0m   ❌ Failed to pull $submodule_name (conflicts or other issues)"
                
                # Show conflict status if any
                if git status --porcelain | grep -q "^UU\|^AA\|^DD"; then
                    echo -e "\033[0;31m[ERROR]\033[0m   🔥 Merge conflicts detected:"
                    git status --porcelain | grep "^UU\|^AA\|^DD"
                fi
                exit 1
            fi
        '
        
        # Check the exit status of git submodule foreach
        local foreach_exit_status=$?
        
        # Count successful submodules (those that didn't error)
        if [[ $foreach_exit_status -eq 0 ]]; then
            successful_submodules=$total_submodules
        else
            # Count how many actually succeeded by checking git submodule status
            successful_submodules=$(git submodule status | grep -v "^-" | wc -l)
            submodule_errors=$((total_submodules - successful_submodules))
        fi
        
        echo ""
    fi
    
    print_info "=========================================="
    print_info "PHASE 2: Pulling main meta repository"
    print_info "=========================================="
    
    # Check for uncommitted changes in main repo
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        print_warning "⚠️  Uncommitted changes detected in main repository"
        git status --porcelain
        print_warning "🔄 Stashing changes before pull..."
        git stash push -m "Auto-stash main repo before pull-all at $(date)" >/dev/null 2>&1
    fi
    
    # Get current branch of main repo
    main_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        print_error "❌ Failed to get current branch for main repository"
        main_repo_error=1
    else
        print_info "📍 Main repo current branch: $main_branch"
        
        # Fetch main repo
        print_info "🔄 Fetching main repository from origin..."
        if ! git fetch origin >/dev/null 2>&1; then
            print_error "❌ Failed to fetch main repository from origin"
            main_repo_error=1
        else
            # Try to pull main repo
            print_info "🔄 Pulling main repository ($main_branch)..."
            if git pull origin "$main_branch" >/dev/null 2>&1; then
                print_success "✅ Successfully pulled main repository"
                
                # Update submodule references if needed
                print_info "🔄 Updating submodule references..."
                if git submodule update --remote --merge >/dev/null 2>&1; then
                    print_success "✅ Submodule references updated"
                else
                    print_warning "⚠️  Some submodule references may need manual update"
                fi
            else
                print_error "❌ Failed to pull main repository (conflicts or other issues)"
                main_repo_error=1
                
                # Show conflict status if any
                if git status --porcelain | grep -q "^UU\|^AA\|^DD"; then
                    print_error "🔥 Merge conflicts detected in main repository:"
                    git status --porcelain | grep "^UU\|^AA\|^DD"
                fi
            fi
        fi
    fi
    
    print_info "=========================================="
    print_info "PULL OPERATION SUMMARY"
    print_info "=========================================="
    
    # Final status report
    if [[ $submodule_errors -eq 0 && $main_repo_error -eq 0 ]]; then
        print_success "🎉 ALL REPOSITORIES UP TO DATE!"
        print_success "✅ Submodules processed: $total_submodules (all successful)"
        print_success "✅ Main repository: Successfully updated"
        echo ""
        print_success "🚀 Everything is ready for development!"
    else
        print_error "⚠️  SOME ISSUES ENCOUNTERED:"
        if [[ $submodule_errors -gt 0 ]]; then
            print_error "❌ Submodules with errors: $submodule_errors out of $total_submodules"
            print_success "✅ Submodules successful: $successful_submodules out of $total_submodules"
        fi
        if [[ $main_repo_error -eq 1 ]]; then
            print_error "❌ Main repository: Failed to update"
        fi
        echo ""
        print_error "🔧 Please resolve conflicts manually and try again"
        print_info "💡 Use 'git status' in each problematic repository to see details"
        print_info "💡 Use 'cd [submodule_path] && git status' to check individual submodules"
    fi
    
    # Show final git status
    echo ""
    print_info "📊 Current repository status:"
    git status --porcelain 2>/dev/null || git status -s 2>/dev/null || echo "Clean working directory"
    
    return $((submodule_errors + main_repo_error))
}

# Show status of all repositories
status() {
    print_header
    print_info "Checking status of all repositories..."
    
    local META_ROOT=$(get_meta_root)
    cd "$META_ROOT"
    
    print_info "=========================================="
    print_info "MAIN REPOSITORY STATUS"
    print_info "=========================================="
    
    local main_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    print_info "📍 Current branch: $main_branch"
    
    # Check if main repo has changes
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        print_success "✅ Main repository: Clean working directory"
    else
        print_warning "⚠️  Main repository: Uncommitted changes detected"
        git status --porcelain
    fi
    
    echo ""
    print_info "=========================================="
    print_info "SUBMODULES STATUS"
    print_info "=========================================="
    
    # Check submodules status
    if [[ ! -f ".gitmodules" ]]; then
        print_warning "No .gitmodules file found."
    else
        # Use a simpler approach to avoid potential hanging
        while IFS= read -r line; do
            if [[ $line =~ ^\[submodule.*\"(.*)\" ]]; then
                submodule_name="${BASH_REMATCH[1]}"
                print_info "Checking submodule: $submodule_name"
                
                if [[ -d "$submodule_name" ]]; then
                    cd "$submodule_name"
                    
                    # Get current branch
                    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
                    print_info "  📍 Current branch: $current_branch"
                    
                    # Check for uncommitted changes
                    if git diff-index --quiet HEAD -- 2>/dev/null; then
                        print_success "  ✅ Clean working directory"
                    else
                        print_warning "  ⚠️  Uncommitted changes detected"
                        git status --porcelain | head -3
                    fi
                    
                    cd "$META_ROOT"
                else
                    print_warning "  ⚠️  Submodule directory not found"
                fi
                
                echo ""
            fi
        done < .gitmodules
    fi
}

# Push all submodules and main repo
push_all() {
    print_header
    print_info "Starting comprehensive push operation..."
    
    local META_ROOT=$(get_meta_root)
    cd "$META_ROOT"
    
    local errors=0
    
    print_info "=========================================="
    print_info "PHASE 1: Pushing all submodules"
    print_info "=========================================="
    
    if [[ ! -f ".gitmodules" ]]; then
        print_warning "No .gitmodules file found. Skipping submodule pushes."
    else
        git submodule foreach --recursive '
            submodule_name="$name"
            echo -e "\033[0;34m[INFO]\033[0m Processing submodule: $submodule_name"
            
            current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
            echo -e "\033[0;34m[INFO]\033[0m   📍 Current branch: $current_branch"
            
            # Check if there are commits to push
            git fetch origin >/dev/null 2>&1
            local ahead=$(git rev-list origin/$current_branch..HEAD --count 2>/dev/null)
            
            if [[ $ahead -eq 0 ]]; then
                echo -e "\033[0;32m[SUCCESS]\033[0m   ✅ No commits to push for $submodule_name"
            else
                echo -e "\033[0;34m[INFO]\033[0m   📤 Pushing $ahead commits to origin/$current_branch..."
                if git push origin "$current_branch" >/dev/null 2>&1; then
                    echo -e "\033[0;32m[SUCCESS]\033[0m   ✅ Successfully pushed $submodule_name"
                else
                    echo -e "\033[0;31m[ERROR]\033[0m   ❌ Failed to push $submodule_name"
                    exit 1
                fi
            fi
        '
        
        if [[ $? -ne 0 ]]; then
            errors=$((errors + 1))
        fi
    fi
    
    print_info "=========================================="
    print_info "PHASE 2: Pushing main meta repository"
    print_info "=========================================="
    
    main_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    print_info "📍 Main repo current branch: $main_branch"
    
    # Check if there are commits to push in main repo
    git fetch origin >/dev/null 2>&1
    local ahead=$(git rev-list origin/$main_branch..HEAD --count 2>/dev/null)
    
    if [[ $ahead -eq 0 ]]; then
        print_success "✅ No commits to push for main repository"
    else
        print_info "📤 Pushing $ahead commits to origin/$main_branch..."
        if git push origin "$main_branch" >/dev/null 2>&1; then
            print_success "✅ Successfully pushed main repository"
        else
            print_error "❌ Failed to push main repository"
            errors=$((errors + 1))
        fi
    fi
    
    print_info "=========================================="
    print_info "PUSH OPERATION SUMMARY"
    print_info "=========================================="
    
    if [[ $errors -eq 0 ]]; then
        print_success "🎉 ALL REPOSITORIES PUSHED SUCCESSFULLY!"
        print_success "🚀 All changes are now available on remote!"
    else
        print_error "⚠️  $errors REPOSITORIES FAILED TO PUSH"
        print_error "🔧 Please check the errors above and resolve them manually"
    fi
    
    return $errors
}

# Sync all repositories (pull then push)
sync() {
    print_header
    print_info "Starting comprehensive sync operation (pull + push)..."
    
    # First pull all
    pull_all
    local pull_result=$?
    
    if [[ $pull_result -eq 0 ]]; then
        echo ""
        print_info "Pull completed successfully, proceeding with push..."
        push_all
        local push_result=$?
        return $push_result
    else
        print_error "Pull operation failed. Skipping push to avoid conflicts."
        return $pull_result
    fi
}

# Check for uncommitted changes across all repos
check() {
    print_header
    print_info "Checking for uncommitted changes across all repositories..."
    
    local META_ROOT=$(get_meta_root)
    cd "$META_ROOT"
    
    local has_changes=0
    
    # Check main repo
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        print_warning "⚠️  Main repository has uncommitted changes:"
        git status --porcelain
        has_changes=1
        echo ""
    fi
    
    # Check submodules
    if [[ -f ".gitmodules" ]]; then
        git submodule foreach --recursive '
            if ! git diff-index --quiet HEAD -- 2>/dev/null; then
                echo -e "\033[1;33m[WARNING]\033[0m ⚠️  $name has uncommitted changes:"
                git status --porcelain
                echo ""
                exit 1
            fi
        '
        
        if [[ $? -ne 0 ]]; then
            has_changes=1
        fi
    fi
    
    if [[ $has_changes -eq 0 ]]; then
        print_success "✅ All repositories have clean working directories!"
    else
        print_warning "⚠️  Some repositories have uncommitted changes"
        print_info "💡 Use 'git add' and 'git commit' to commit changes"
        print_info "💡 Or use 'git stash' to temporarily save changes"
    fi
    
    return $has_changes
}

# Main script logic
main() {
    case "${1:-help}" in
        "pull-all")
            pull_all
            ;;
        "status")
            status
            ;;
        "push-all")
            push_all
            ;;
        "sync")
            sync
            ;;
        "check")
            check
            ;;
        "help"|"")
            help
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            help
            exit 1
            ;;
    esac
}

# Run the main function with all arguments
main "$@"
