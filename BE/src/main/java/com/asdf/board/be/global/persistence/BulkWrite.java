package com.asdf.board.be.global.persistence;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.springframework.data.jpa.repository.Modifying;

@Documented
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Modifying(flushAutomatically = true, clearAutomatically = true)
public @interface BulkWrite {
}
