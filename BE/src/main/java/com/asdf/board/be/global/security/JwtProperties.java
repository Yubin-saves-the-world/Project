package com.asdf.board.be.global.security;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "vitality.jwt")
public record JwtProperties(String secret, Duration expiresIn) {
}
