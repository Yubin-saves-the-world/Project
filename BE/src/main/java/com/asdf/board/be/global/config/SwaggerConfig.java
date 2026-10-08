package com.asdf.board.be.global.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.media.Schema;
import io.swagger.v3.oas.models.servers.Server;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import org.springdoc.core.customizers.OpenApiCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class SwaggerConfig {

    private static final String BEARER_SCHEME = "bearerAuth";

    @Bean
    OpenAPI openAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Project Vitality API")
                        .description("로그인 후 받은 access_token을 우측 상단 Authorize에 붙여 넣으면 인증이 필요한 API도 호출할 수 있습니다.")
                        .version("v1"))
                .addServersItem(new Server().url("/").description("현재 서버"))
                .components(new Components().addSecuritySchemes(BEARER_SCHEME, new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")))
                .addSecurityItem(new SecurityRequirement().addList(BEARER_SCHEME));
    }

    @Bean
    OpenApiCustomizer snakeCaseSchemaProperties() {
        return openApi -> {
            if (openApi.getComponents() == null || openApi.getComponents().getSchemas() == null) {
                return;
            }
            openApi.getComponents().getSchemas().values().forEach(SwaggerConfig::toSnakeCase);
        };
    }

    @SuppressWarnings({"rawtypes", "unchecked"})
    private static void toSnakeCase(Schema schema) {
        Map<String, Schema> properties = schema.getProperties();
        if (properties != null) {
            Map<String, Schema> renamed = new LinkedHashMap<>();
            properties.forEach((name, value) -> renamed.put(snake(name), value));
            schema.setProperties(renamed);
        }
        if (schema.getRequired() != null) {
            schema.setRequired(((java.util.List<String>) schema.getRequired()).stream().map(SwaggerConfig::snake).toList());
        }
    }

    private static String snake(String name) {
        return name.replaceAll("([a-z0-9])([A-Z])", "$1_$2").toLowerCase(Locale.ROOT);
    }
}
