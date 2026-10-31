package com.asdf.board.be;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

// Context smoke test is isolated from the developer's MySQL database.
@SpringBootTest(properties = {
    "spring.datasource.url=jdbc:h2:mem:movid-context;MODE=MySQL;DB_CLOSE_DELAY=-1",
    "spring.datasource.driver-class-name=org.h2.Driver",
    "spring.datasource.username=sa",
    "spring.datasource.password=",
    "spring.flyway.enabled=false",
    "spring.jpa.hibernate.ddl-auto=create-drop",
    "vitality.storage-dir=${java.io.tmpdir}/movid-context-photos"
})
class BeApplicationTests {

    @Test
    void contextLoads() {
    }

}
