package com.asdf.board.be.community.dto;

import org.springframework.data.domain.Page;

import java.util.List;
import java.util.function.Function;

public record PageResult<T>(List<T> items, int page, long total) {

    public static <E, D> PageResult<D> from(Page<E> pageData, Function<E, D> mapper) {
        return new PageResult<>(
                pageData.getContent().stream().map(mapper).toList(),
                pageData.getNumber() + 1,
                pageData.getTotalElements()
        );
    }
}
