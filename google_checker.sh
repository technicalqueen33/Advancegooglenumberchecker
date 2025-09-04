#!/data/data/com.termux/files/usr/bin/bash

# Advanced Google Number Checker
# Author: Termux Script
# Version: 2.0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
THREADS=5
TIMEOUT=10
RETRY=2
DELAY=1

# Output files
VALID_FILE="valid_numbers.txt"
INVALID_FILE="invalid_numbers.txt"
UNKNOWN_FILE="unknown_numbers.txt"
LOG_FILE="checker_log.txt"

# Banner
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║           GOOGLE NUMBER CHECKER v2.0            ║"
    echo "║          Advanced Bulk Verification             ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}[!] Educational purposes only${NC}"
    echo -e "${YELLOW}[!] Use responsibly${NC}"
    echo ""
}

# Check dependencies
check_dependencies() {
    local deps=("curl" "jq" "parallel")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}[ERROR] Missing dependencies:${NC}"
        for dep in "${missing[@]}"; do
            echo -e "  - $dep"
        done
        echo -e "\n${YELLOW}Install with: pkg install ${missing[*]}${NC}"
        exit 1
    fi
}

# Generate user agents
random_user_agent() {
    local agents=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
        "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15"
    )
    echo "${agents[$RANDOM % ${#agents[@]}]}"
}

# Check single number
check_number() {
    local number="$1"
    local attempt=0
    
    while [ $attempt -lt $RETRY ]; do
        local response=$(curl -s -k -L \
            -H "User-Agent: $(random_user_agent)" \
            -H "Accept: application/json" \
            -H "Accept-Language: en-US,en;q=0.9" \
            -H "Connection: keep-alive" \
            -m $TIMEOUT \
            "https://accounts.google.com/_/signup/websignaldiagnostics?hl=en" \
            --data-raw "[[\"gf.sd\",\"$number\",null,1]]" 2>/dev/null)
        
        if [ $? -eq 0 ] && [ -n "$response" ]; then
            if echo "$response" | grep -q "ACCOUNT_EXISTS"; then
                echo "VALID"
                return 0
            elif echo "$response" | grep -q "TOO_MANY_ATTEMPTS_TRY_LATER"; then
                echo "RATE_LIMIT"
                return 2
            elif echo "$response" | grep -q "NOT_ENOUGH_INFORMATION"; then
                echo "INVALID"
                return 0
            fi
        fi
        
        attempt=$((attempt + 1))
        sleep $DELAY
    done
    
    echo "UNKNOWN"
    return 1
}

# Process number with logging
process_number() {
    local number=$(echo "$1" | tr -d ' ' | tr -d '+' | tr -d '-')
    
    if [[ ! "$number" =~ ^[0-9]{8,15}$ ]]; then
        echo -e "${RED}[INVALID_FORMAT] $number${NC}" | tee -a "$LOG_FILE"
        return
    fi
    
    echo -e "${BLUE}[CHECKING] $number${NC}" | tee -a "$LOG_FILE"
    local result=$(check_number "$number")
    
    case $result in
        "VALID")
            echo -e "${GREEN}[REGISTERED] $number${NC}" | tee -a "$LOG_FILE"
            echo "$number" >> "$VALID_FILE"
            ;;
        "INVALID")
            echo -e "${YELLOW}[NOT_REGISTERED] $number${NC}" | tee -a "$LOG_FILE"
            echo "$number" >> "$INVALID_FILE"
            ;;
        "RATE_LIMIT")
            echo -e "${RED}[RATE_LIMITED] $number - Waiting...${NC}" | tee -a "$LOG_FILE"
            sleep 5
            process_number "$number"
            ;;
        *)
            echo -e "${RED}[UNKNOWN] $number -可能需要重试${NC}" | tee -a "$LOG_FILE"
            echo "$number" >> "$UNKNOWN_FILE"
            ;;
    esac
}

# Export function for parallel
export -f process_number check_number random_user_agent
export RED GREEN YELLOW BLUE CYAN NC LOG_FILE VALID_FILE INVALID_FILE UNKNOWN_FILE

# Main function
main() {
    print_banner
    check_dependencies
    
    echo -e "${CYAN}[*] Setting up environment...${NC}"
    
    # Create output files
    > "$VALID_FILE"
    > "$INVALID_FILE"
    > "$UNKNOWN_FILE"
    > "$LOG_FILE"
    
    echo -e "${CYAN}[*] Enter the path to your numbers file:${NC}"
    echo -e "${YELLOW}[?] File should contain one number per line${NC}"
    read -p "File path: " input_file
    
    if [ ! -f "$input_file" ]; then
        echo -e "${RED}[ERROR] File not found: $input_file${NC}"
        exit 1
    fi
    
    local total_lines=$(wc -l < "$input_file")
    echo -e "${GREEN}[*] Found $total_lines numbers to check${NC}"
    
    echo -e "${CYAN}[*] Starting verification...${NC}"
    echo -e "${YELLOW}[!] Press Ctrl+C to stop${NC}"
    echo ""
    
    # Process numbers in parallel
    cat "$input_file" | parallel -j $THREADS process_number {}
    
    # Generate report
    local valid_count=$(wc -l < "$VALID_FILE" 2>/dev/null || echo 0)
    local invalid_count=$(wc -l < "$INVALID_FILE" 2>/dev/null || echo 0)
    local unknown_count=$(wc -l < "$UNKNOWN_FILE" 2>/dev/null || echo 0)
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════╗"
    echo -e "║               CHECKING COMPLETE             ║"
    echo -e "╚══════════════════════════════════════════╝${NC}"
    echo -e "${GREEN}✅ Registered: $valid_count${NC}"
    echo -e "${YELLOW}❌ Not Registered: $invalid_count${NC}"
    echo -e "${RED}❓ Unknown: $unknown_count${NC}"
    echo -e "${BLUE}📊 Total: $total_lines${NC}"
    echo ""
    echo -e "${CYAN}📁 Output files:${NC}"
    echo -e "  Valid: $VALID_FILE"
    echo -e "  Invalid: $INVALID_FILE"
    echo -e "  Unknown: $UNKNOWN_FILE"
    echo -e "  Log: $LOG_FILE"
}

# Handle interrupt
trap 'echo -e "\n${RED}[!] Script interrupted by user${NC}"; exit 1' INT

# Run main function

main "$@"
