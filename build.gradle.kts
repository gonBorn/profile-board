plugins {
  java
  id("org.jlleitschuh.gradle.ktlint") version "12.3.0"
  id("org.springframework.boot") version "3.5.4"
  id("io.spring.dependency-management") version "1.1.7"
}

group = "io.github.gonborn"
version = "0.0.1-SNAPSHOT"
description = "profile-board"

java {
  toolchain {
    languageVersion = JavaLanguageVersion.of(21)
  }
}

repositories {
  mavenCentral()
}

dependencies {
//    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
  implementation("org.springframework.boot:spring-boot-starter-web")
  testImplementation("org.springframework.boot:spring-boot-starter-test")
  testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<Test> {
  useJUnitPlatform()
}
