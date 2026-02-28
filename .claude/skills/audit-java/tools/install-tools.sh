#!/bin/bash
# Java Static Analysis Tools Installation Guide
# This script guides you through installing all recommended tools for Java audit

echo "======================================"
echo "Java Static Analysis Tools Installer"
echo "======================================"
echo ""

# Check Java installation
echo "Checking prerequisites..."
if ! command -v java &> /dev/null; then
    echo "❌ Java is not installed. Please install JDK 11 or higher."
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
echo "✅ Java $JAVA_VERSION detected"

# Check Maven or Gradle
if command -v mvn &> /dev/null; then
    echo "✅ Maven detected: $(mvn -version | head -1)"
elif command -v gradle &> /dev/null; then
    echo "✅ Gradle detected: $(gradle --version | grep Gradle)"
else
    echo "⚠️  Neither Maven nor Gradle found. Install one for best results."
fi

echo ""
echo "========================================="
echo "Tier 1: Essential Tools (Recommended)"
echo "========================================="

# 1. Semgrep
echo ""
echo "1. Semgrep (OWASP Top 10, CWE/SANS 25, JWT/OAuth)"
if command -v semgrep &> /dev/null; then
    echo "   ✅ Already installed: $(semgrep --version)"
else
    echo "   ❌ Not installed"
    echo "   Install with: pip3 install semgrep"
    echo "   Or: brew install semgrep (macOS)"
fi

# 2. Snyk
echo ""
echo "2. Snyk (OWASP Top 10, Deps/CVE scanning)"
if command -v snyk &> /dev/null; then
    echo "   ✅ Already installed: $(snyk --version)"
    echo "   Run 'snyk auth' if not authenticated"
else
    echo "   ❌ Not installed"
    echo "   Install with: npm install -g snyk"
    echo "   Then run: snyk auth (requires free account)"
fi

# 3. SpotBugs + Find Security Bugs
echo ""
echo "3. SpotBugs + Find Security Bugs (OWASP Top 10, CWE)"
echo "   Add to pom.xml (Maven):"
cat << 'EOF'
   <build>
     <plugins>
       <plugin>
         <groupId>com.github.spotbugs</groupId>
         <artifactId>spotbugs-maven-plugin</artifactId>
         <version>4.7.3.6</version>
         <dependencies>
           <dependency>
             <groupId>com.h3xstream.findsecbugs</groupId>
             <artifactId>findsecbugs-plugin</artifactId>
             <version>1.12.0</version>
           </dependency>
         </dependencies>
       </plugin>
     </plugins>
   </build>
EOF

echo ""
echo "   Add to build.gradle (Gradle):"
cat << 'EOF'
   plugins {
       id 'com.github.spotbugs' version '5.0.14'
   }
   spotbugs {
       toolVersion = '4.7.3'
   }
   dependencies {
       spotbugsPlugins 'com.h3xstream.findsecbugs:findsecbugs-plugin:1.12.0'
   }
EOF

# 4. PMD
echo ""
echo "4. PMD (Code quality, complexity detection)"
echo "   Add to pom.xml (Maven):"
cat << 'EOF'
   <build>
     <plugins>
       <plugin>
         <groupId>org.apache.maven.plugins</groupId>
         <artifactId>maven-pmd-plugin</artifactId>
         <version>3.21.0</version>
       </plugin>
     </plugins>
   </build>
EOF

echo ""
echo "   Add to build.gradle (Gradle):"
cat << 'EOF'
   plugins {
       id 'pmd'
   }
   pmd {
       toolVersion = '6.55.0'
       ruleSets = ['category/java/bestpractices.xml',
                   'category/java/security.xml']
   }
EOF

echo ""
echo "========================================="
echo "Tier 2: Recommended Tools"
echo "========================================="

# 5. Checkstyle
echo ""
echo "5. Checkstyle (Code style, consistency)"
echo "   Add to pom.xml (Maven):"
cat << 'EOF'
   <build>
     <plugins>
       <plugin>
         <groupId>org.apache.maven.plugins</groupId>
         <artifactId>maven-checkstyle-plugin</artifactId>
         <version>3.3.0</version>
       </plugin>
     </plugins>
   </build>
EOF

echo ""
echo "   Add to build.gradle (Gradle):"
cat << 'EOF'
   plugins {
       id 'checkstyle'
   }
   checkstyle {
       toolVersion = '10.12.0'
   }
EOF

# 6. OWASP Dependency-Check
echo ""
echo "6. OWASP Dependency-Check (CVE scanning)"
if command -v dependency-check &> /dev/null; then
    echo "   ✅ Already installed"
else
    echo "   ❌ Not installed"
    echo "   Install with: brew install dependency-check (macOS)"
    echo "   Or download from: https://github.com/jeremylong/DependencyCheck/releases"
fi

echo "   Add to pom.xml (Maven):"
cat << 'EOF'
   <build>
     <plugins>
       <plugin>
         <groupId>org.owasp</groupId>
         <artifactId>dependency-check-maven</artifactId>
         <version>8.4.0</version>
       </plugin>
     </plugins>
   </build>
EOF

echo ""
echo "   Add to build.gradle (Gradle):"
cat << 'EOF'
   plugins {
       id 'org.owasp.dependencycheck' version '8.4.0'
   }
EOF

# 7. Trivy
echo ""
echo "7. Trivy (Container/IaC/12-Factor scanning)"
if command -v trivy &> /dev/null; then
    echo "   ✅ Already installed: $(trivy --version)"
else
    echo "   ❌ Not installed"
    echo "   Install with: brew install aquasecurity/trivy/trivy (macOS)"
    echo "   Or see: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
fi

# 8. SonarQube Scanner
echo ""
echo "8. SonarQube Scanner (Comprehensive analysis)"
if command -v sonar-scanner &> /dev/null; then
    echo "   ✅ Already installed"
else
    echo "   ❌ Not installed (optional)"
    echo "   Install with: brew install sonar-scanner (macOS)"
    echo "   Requires SonarQube server or SonarCloud account"
fi

echo ""
echo "========================================="
echo "Installation Summary"
echo "========================================="
echo ""
echo "Checking installed tools..."

INSTALLED=0
TOTAL=8

command -v semgrep &> /dev/null && echo "✅ Semgrep" && ((INSTALLED++)) || echo "❌ Semgrep"
command -v snyk &> /dev/null && echo "✅ Snyk" && ((INSTALLED++)) || echo "❌ Snyk"
grep -q "spotbugs" pom.xml build.gradle build.gradle.kts 2>/dev/null && echo "✅ SpotBugs (configured)" && ((INSTALLED++)) || echo "❌ SpotBugs (not configured)"
grep -q "pmd" pom.xml build.gradle build.gradle.kts 2>/dev/null && echo "✅ PMD (configured)" && ((INSTALLED++)) || echo "❌ PMD (not configured)"
grep -q "checkstyle" pom.xml build.gradle build.gradle.kts 2>/dev/null && echo "✅ Checkstyle (configured)" && ((INSTALLED++)) || echo "❌ Checkstyle (not configured)"
command -v dependency-check &> /dev/null && echo "✅ OWASP Dependency-Check" && ((INSTALLED++)) || echo "❌ OWASP Dependency-Check"
command -v trivy &> /dev/null && echo "✅ Trivy" && ((INSTALLED++)) || echo "❌ Trivy"
command -v sonar-scanner &> /dev/null && echo "✅ SonarQube Scanner" && ((INSTALLED++)) || echo "❌ SonarQube Scanner"

echo ""
echo "Tools installed: $INSTALLED/$TOTAL"

if [ $INSTALLED -ge 4 ]; then
    echo "✅ Good! You have enough tools for high-quality analysis."
elif [ $INSTALLED -ge 2 ]; then
    echo "⚠️  You have basic coverage. Install more tools for better results."
else
    echo "❌ Install at least Semgrep and Snyk for meaningful analysis."
fi

echo ""
echo "========================================="
echo "Next Steps"
echo "========================================="
echo ""
echo "1. Install missing tools using the commands above"
echo "2. For build plugins (SpotBugs, PMD, Checkstyle), add to pom.xml or build.gradle"
echo "3. Run: /audit-java in your Java project"
echo "4. The audit will use all available tools automatically"
echo ""
echo "The audit system gracefully handles missing tools - it will run with what's available."
echo ""
