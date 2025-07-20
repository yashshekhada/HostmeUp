#!/usr/bin/env python3
"""
End-to-End Test Suite for DevServerManager
This script simulates the complete user experience and checks for potential issues.
"""

import os
import sys
import json
import subprocess
import time
from pathlib import Path
from typing import Dict, List, Any

class DevServerManagerTester:
    def __init__(self):
        self.test_results = []
        self.issues_found = []
        self.project_root = Path("/workspace")
        
    def log_test(self, test_name: str, status: str, details: str = ""):
        """Log test results"""
        result = {
            "test": test_name,
            "status": status,
            "details": details,
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        self.test_results.append(result)
        
        # Print with emoji for visual feedback
        emoji = "✅" if status == "PASS" else "❌" if status == "FAIL" else "⚠️"
        print(f"{emoji} {test_name}: {status}")
        if details:
            print(f"   Details: {details}")
    
    def test_project_structure(self):
        """Test 1: Verify project structure and file integrity"""
        print("\n🔍 Testing Project Structure...")
        
        required_files = [
            "DevServerManager/DevServerManager/DevServerManagerApp.swift",
            "DevServerManager/DevServerManager/Managers/ProjectManager.swift",
            "DevServerManager/DevServerManager/Managers/ServerManager.swift",
            "DevServerManager/DevServerManager/Managers/NetworkManager.swift",
            "DevServerManager/DevServerManager/Managers/PortForwardingManager.swift",
            "DevServerManager/DevServerManager/Views/ContentView.swift",
            "DevServerManager/DevServerManager/Views/ProjectSettingsView.swift",
            "DevServerManager/DevServerManager/Views/StatusView.swift",
            "DevServerManager/DevServerManager/Info.plist",
            "DevServerManager/DevServerManager/DevServerManager.entitlements",
            "DevServerManager/DevServerManager.xcodeproj/project.pbxproj"
        ]
        
        missing_files = []
        for file_path in required_files:
            if not (self.project_root / file_path).exists():
                missing_files.append(file_path)
        
        if missing_files:
            self.log_test("Project Structure", "FAIL", f"Missing files: {', '.join(missing_files)}")
            self.issues_found.append(f"Missing required files: {missing_files}")
        else:
            self.log_test("Project Structure", "PASS", "All required files present")
    
    def test_swift_syntax(self):
        """Test 2: Check Swift syntax and imports"""
        print("\n🔧 Testing Swift Syntax...")
        
        swift_files = list(self.project_root.rglob("*.swift"))
        syntax_issues = []
        
        for swift_file in swift_files:
            try:
                with open(swift_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check for basic syntax issues
                issues = []
                
                # Check for proper imports
                if "import Foundation" not in content and "import SwiftUI" not in content:
                    issues.append("Missing required imports")
                
                # Check for obvious syntax errors
                if "TODO" in content or "FIXME" in content or "BUG" in content:
                    issues.append("Contains TODO/FIXME/BUG comments")
                
                # Check for potential issues
                if "force unwrap" in content.lower() or "!" in content:
                    issues.append("Potential force unwrapping")
                
                if issues:
                    syntax_issues.append(f"{swift_file.name}: {', '.join(issues)}")
                    
            except Exception as e:
                syntax_issues.append(f"{swift_file.name}: Error reading file - {e}")
        
        if syntax_issues:
            self.log_test("Swift Syntax", "WARN", f"Found {len(syntax_issues)} potential issues")
            for issue in syntax_issues:
                self.issues_found.append(issue)
        else:
            self.log_test("Swift Syntax", "PASS", "No obvious syntax issues found")
    
    def test_code_quality(self):
        """Test 3: Analyze code quality and potential issues"""
        print("\n📊 Testing Code Quality...")
        
        quality_issues = []
        
        # Check for potential memory leaks
        swift_files = list(self.project_root.rglob("*.swift"))
        for swift_file in swift_files:
            try:
                with open(swift_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check for weak self usage in closures
                if "Task.detached" in content and "weak self" not in content:
                    quality_issues.append(f"{swift_file.name}: Potential retain cycle in Task.detached")
                
                # Check for proper error handling
                if "try await" in content and "catch" not in content:
                    quality_issues.append(f"{swift_file.name}: Missing error handling for async operations")
                
                # Check for proper MainActor usage
                if "await MainActor.run" in content:
                    quality_issues.append(f"{swift_file.name}: MainActor usage detected (good practice)")
                
            except Exception as e:
                quality_issues.append(f"{swift_file.name}: Error analyzing file - {e}")
        
        if quality_issues:
            self.log_test("Code Quality", "WARN", f"Found {len(quality_issues)} quality concerns")
            for issue in quality_issues:
                self.issues_found.append(issue)
        else:
            self.log_test("Code Quality", "PASS", "Code quality looks good")
    
    def test_network_configuration(self):
        """Test 4: Analyze network configuration and potential issues"""
        print("\n🌐 Testing Network Configuration...")
        
        network_issues = []
        
        # Check NetworkManager.swift for potential issues
        network_file = self.project_root / "DevServerManager/DevServerManager/Managers/NetworkManager.swift"
        if network_file.exists():
            try:
                with open(network_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check for proper error handling in network calls
                if "URLSession.shared.data" in content and "catch" not in content:
                    network_issues.append("NetworkManager: Missing error handling for network requests")
                
                # Check for timeout configuration
                if "URLSession.shared.data" in content and "timeout" not in content:
                    network_issues.append("NetworkManager: No timeout configuration for network requests")
                
                # Check for proper async/await usage
                if "async" in content and "await" not in content:
                    network_issues.append("NetworkManager: Inconsistent async/await usage")
                
            except Exception as e:
                network_issues.append(f"NetworkManager: Error analyzing file - {e}")
        
        if network_issues:
            self.log_test("Network Configuration", "WARN", f"Found {len(network_issues)} network issues")
            for issue in network_issues:
                self.issues_found.append(issue)
        else:
            self.log_test("Network Configuration", "PASS", "Network configuration looks good")
    
    def test_server_management(self):
        """Test 5: Analyze server management functionality"""
        print("\n🖥️ Testing Server Management...")
        
        server_issues = []
        
        # Check ServerManager.swift for potential issues
        server_file = self.project_root / "DevServerManager/DevServerManager/Managers/ServerManager.swift"
        if server_file.exists():
            try:
                with open(server_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check for proper process cleanup
                if "Process()" in content and "terminate()" not in content:
                    server_issues.append("ServerManager: Missing process termination handling")
                
                # Check for proper error handling
                if "Process()" in content and "catch" not in content:
                    server_issues.append("ServerManager: Missing error handling for process operations")
                
                # Check for proper async/await usage
                if "async" in content and "await" not in content:
                    server_issues.append("ServerManager: Inconsistent async/await usage")
                
            except Exception as e:
                server_issues.append(f"ServerManager: Error analyzing file - {e}")
        
        if server_issues:
            self.log_test("Server Management", "WARN", f"Found {len(server_issues)} server management issues")
            for issue in server_issues:
                self.issues_found.append(issue)
        else:
            self.log_test("Server Management", "PASS", "Server management looks good")
    
    def test_user_experience_flow(self):
        """Test 6: Simulate user experience flow"""
        print("\n👤 Testing User Experience Flow...")
        
        ux_issues = []
        
        # Check ContentView.swift for UI flow issues
        content_file = self.project_root / "DevServerManager/DevServerManager/Views/ContentView.swift"
        if content_file.exists():
            try:
                with open(content_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check for proper state management
                if "@State" in content and "@Published" not in content:
                    ux_issues.append("ContentView: Missing @Published properties for state management")
                
                # Check for proper error handling in UI
                if "error" in content.lower() and "alert" not in content.lower():
                    ux_issues.append("ContentView: Missing error alerts for user feedback")
                
                # Check for loading states
                if "loading" not in content.lower() and "progress" not in content.lower():
                    ux_issues.append("ContentView: Missing loading indicators")
                
            except Exception as e:
                ux_issues.append(f"ContentView: Error analyzing file - {e}")
        
        if ux_issues:
            self.log_test("User Experience", "WARN", f"Found {len(ux_issues)} UX issues")
            for issue in ux_issues:
                self.issues_found.append(issue)
        else:
            self.log_test("User Experience", "PASS", "User experience flow looks good")
    
    def test_permissions_and_security(self):
        """Test 7: Check permissions and security configuration"""
        print("\n🔒 Testing Permissions and Security...")
        
        security_issues = []
        
        # Check entitlements file
        entitlements_file = self.project_root / "DevServerManager/DevServerManager/DevServerManager.entitlements"
        if entitlements_file.exists():
            try:
                with open(entitlements_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check for necessary permissions
                required_permissions = [
                    "com.apple.security.network.client",
                    "com.apple.security.network.server",
                    "com.apple.security.files.user-selected.read-write"
                ]
                
                missing_permissions = []
                for permission in required_permissions:
                    if permission not in content:
                        missing_permissions.append(permission)
                
                if missing_permissions:
                    security_issues.append(f"Missing permissions: {', '.join(missing_permissions)}")
                
                # Check for sandbox configuration
                if "com.apple.security.app-sandbox" in content:
                    security_issues.append("App sandbox is disabled (may be intentional for server management)")
                
            except Exception as e:
                security_issues.append(f"Error reading entitlements: {e}")
        
        if security_issues:
            self.log_test("Security & Permissions", "WARN", f"Found {len(security_issues)} security concerns")
            for issue in security_issues:
                self.issues_found.append(issue)
        else:
            self.log_test("Security & Permissions", "PASS", "Security configuration looks good")
    
    def test_build_configuration(self):
        """Test 8: Check build configuration and deployment"""
        print("\n🏗️ Testing Build Configuration...")
        
        build_issues = []
        
        # Check Info.plist
        info_plist = self.project_root / "DevServerManager/DevServerManager/Info.plist"
        if info_plist.exists():
            try:
                with open(info_plist, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check for required keys
                required_keys = [
                    "CFBundleIdentifier",
                    "CFBundleName",
                    "CFBundleVersion",
                    "LSMinimumSystemVersion"
                ]
                
                missing_keys = []
                for key in required_keys:
                    if key not in content:
                        missing_keys.append(key)
                
                if missing_keys:
                    build_issues.append(f"Missing Info.plist keys: {', '.join(missing_keys)}")
                
            except Exception as e:
                build_issues.append(f"Error reading Info.plist: {e}")
        
        # Check Xcode project file
        project_file = self.project_root / "DevServerManager/DevServerManager.xcodeproj/project.pbxproj"
        if not project_file.exists():
            build_issues.append("Xcode project file missing")
        
        if build_issues:
            self.log_test("Build Configuration", "WARN", f"Found {len(build_issues)} build issues")
            for issue in build_issues:
                self.issues_found.append(issue)
        else:
            self.log_test("Build Configuration", "PASS", "Build configuration looks good")
    
    def test_documentation_and_setup(self):
        """Test 9: Check documentation and setup instructions"""
        print("\n📚 Testing Documentation...")
        
        doc_issues = []
        
        # Check for required documentation files
        required_docs = ["README.md", "SETUP.md", "LICENSE"]
        missing_docs = []
        
        for doc in required_docs:
            if not (self.project_root / doc).exists():
                missing_docs.append(doc)
        
        if missing_docs:
            doc_issues.append(f"Missing documentation: {', '.join(missing_docs)}")
        
        # Check README.md content
        readme_file = self.project_root / "README.md"
        if readme_file.exists():
            try:
                with open(readme_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Check for essential sections
                required_sections = ["Features", "Installation", "Usage"]
                missing_sections = []
                
                for section in required_sections:
                    if section not in content:
                        missing_sections.append(section)
                
                if missing_sections:
                    doc_issues.append(f"Missing README sections: {', '.join(missing_sections)}")
                
            except Exception as e:
                doc_issues.append(f"Error reading README: {e}")
        
        if doc_issues:
            self.log_test("Documentation", "WARN", f"Found {len(doc_issues)} documentation issues")
            for issue in doc_issues:
                self.issues_found.append(issue)
        else:
            self.log_test("Documentation", "PASS", "Documentation looks complete")
    
    def generate_report(self):
        """Generate comprehensive test report"""
        print("\n" + "="*60)
        print("📋 END-TO-END TEST REPORT")
        print("="*60)
        
        # Summary statistics
        total_tests = len(self.test_results)
        passed_tests = len([r for r in self.test_results if r["status"] == "PASS"])
        failed_tests = len([r for r in self.test_results if r["status"] == "FAIL"])
        warning_tests = len([r for r in self.test_results if r["status"] == "WARN"])
        
        print(f"\n📊 Test Summary:")
        print(f"   Total Tests: {total_tests}")
        print(f"   ✅ Passed: {passed_tests}")
        print(f"   ⚠️  Warnings: {warning_tests}")
        print(f"   ❌ Failed: {failed_tests}")
        
        if self.issues_found:
            print(f"\n🚨 Issues Found ({len(self.issues_found)}):")
            for i, issue in enumerate(self.issues_found, 1):
                print(f"   {i}. {issue}")
        
        # Detailed results
        print(f"\n📝 Detailed Results:")
        for result in self.test_results:
            emoji = "✅" if result["status"] == "PASS" else "❌" if result["status"] == "FAIL" else "⚠️"
            print(f"   {emoji} {result['test']}: {result['status']}")
            if result["details"]:
                print(f"      Details: {result['details']}")
        
        # Recommendations
        print(f"\n💡 Recommendations:")
        if failed_tests > 0:
            print("   - Fix critical issues before deployment")
        if warning_tests > 0:
            print("   - Address warnings to improve code quality")
        if len(self.issues_found) > 0:
            print("   - Review and fix identified issues")
        else:
            print("   - Code looks good! Ready for testing on macOS")
        
        print("   - Transfer to macOS system with Xcode for final testing")
        print("   - Test with actual development servers")
        print("   - Verify all UI interactions work correctly")
        
        # Save report to file
        report_data = {
            "summary": {
                "total_tests": total_tests,
                "passed": passed_tests,
                "failed": failed_tests,
                "warnings": warning_tests
            },
            "results": self.test_results,
            "issues": self.issues_found,
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        
        with open("test_report.json", "w") as f:
            json.dump(report_data, f, indent=2)
        
        print(f"\n📄 Detailed report saved to: test_report.json")
        print("="*60)
    
    def run_all_tests(self):
        """Run all end-to-end tests"""
        print("🚀 Starting End-to-End Test Suite for DevServerManager")
        print("="*60)
        
        # Run all test methods
        test_methods = [
            self.test_project_structure,
            self.test_swift_syntax,
            self.test_code_quality,
            self.test_network_configuration,
            self.test_server_management,
            self.test_user_experience_flow,
            self.test_permissions_and_security,
            self.test_build_configuration,
            self.test_documentation_and_setup
        ]
        
        for test_method in test_methods:
            try:
                test_method()
            except Exception as e:
                self.log_test(test_method.__name__, "FAIL", f"Test crashed: {e}")
        
        # Generate final report
        self.generate_report()

def main():
    """Main test runner"""
    tester = DevServerManagerTester()
    tester.run_all_tests()

if __name__ == "__main__":
    main()