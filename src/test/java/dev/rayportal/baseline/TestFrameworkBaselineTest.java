package dev.rayportal.baseline;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertTrue;

final class TestFrameworkBaselineTest {
    @Test
    void junitPlatformExecutes() {
        assertTrue(true, "The RayPortal unit-test baseline must execute through Gradle.");
    }
}
