package com.asdf.board.be.global.security;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import java.nio.charset.StandardCharsets;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.oauth2.server.resource.web.BearerTokenResolver;
import org.springframework.security.oauth2.server.resource.web.DefaultBearerTokenResolver;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.util.matcher.OrRequestMatcher;
import org.springframework.security.web.servlet.util.matcher.PathPatternRequestMatcher;
import org.springframework.security.web.util.matcher.RequestMatcher;

@Configuration
@EnableWebSecurity
@EnableConfigurationProperties(JwtProperties.class)
@RequiredArgsConstructor
public class SecurityConfig {

    private static final int MIN_SECRET_BYTES = 32;

    private final JwtProperties jwtProperties;

    @Bean
    SecurityFilterChain securityFilterChain(
            HttpSecurity http, JwtAuthenticationConverter converter, ApiErrorHandlers errorHandlers) throws Exception {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(a -> a
                        .requestMatchers(publicEndpoints()).permitAll()
                        .anyRequest().authenticated())
                .exceptionHandling(e -> e
                        .authenticationEntryPoint(errorHandlers)
                        .accessDeniedHandler(errorHandlers))
                .oauth2ResourceServer(o -> o
                        .bearerTokenResolver(publicAwareBearerTokenResolver())
                        .authenticationEntryPoint(errorHandlers)
                        .accessDeniedHandler(errorHandlers)
                        .jwt(j -> j.jwtAuthenticationConverter(converter)));
        return http.build();
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    JwtEncoder jwtEncoder() {
        return new NimbusJwtEncoder(new ImmutableSecret<>(secretKey()));
    }

    @Bean
    JwtDecoder jwtDecoder() {
        return NimbusJwtDecoder.withSecretKey(secretKey()).macAlgorithm(MacAlgorithm.HS256).build();
    }

    private SecretKey secretKey() {
        byte[] bytes = jwtProperties.secret().getBytes(StandardCharsets.UTF_8);
        if (bytes.length < MIN_SECRET_BYTES) {
            throw new IllegalStateException("vitality.jwt.secret 은 32바이트 이상이어야 합니다.");
        }
        return new SecretKeySpec(bytes, "HmacSHA256");
    }

    private RequestMatcher[] publicEndpoints() {
        return new RequestMatcher[] {
                PathPatternRequestMatcher.pathPattern(HttpMethod.POST, "/api/users"),
                PathPatternRequestMatcher.pathPattern(HttpMethod.POST, "/api/auth/login"),
                PathPatternRequestMatcher.pathPattern("/actuator/health"),
                PathPatternRequestMatcher.pathPattern("/swagger-ui.html"),
                PathPatternRequestMatcher.pathPattern("/swagger-ui/**"),
                PathPatternRequestMatcher.pathPattern("/v3/api-docs/**")
        };
    }

    private BearerTokenResolver publicAwareBearerTokenResolver() {
        RequestMatcher isPublic = new OrRequestMatcher(publicEndpoints());
        DefaultBearerTokenResolver delegate = new DefaultBearerTokenResolver();
        return request -> isPublic.matches(request) ? null : delegate.resolve(request);
    }
}
