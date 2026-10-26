package com.asdf.board.be.global.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(VitalityProperties.class)
public class PropertiesConfig {
}
