package com.asdf.board.be.global.web;

import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

public final class PageParams {

    public static final int MAX_SIZE = 50;

    private static final int MAX_PAGE_INDEX = Integer.MAX_VALUE / MAX_SIZE - 1;

    private PageParams() {
    }

    public static PageRequest of(int page, int pageSize, Sort sort) {
        return PageRequest.of(Math.min(page - 1, MAX_PAGE_INDEX), pageSize, sort);
    }

    public static <T> List<T> slice(List<T> all, int page, int pageSize) {
        int from = (int) Math.min((long) (page - 1) * pageSize, all.size());
        return all.subList(from, Math.min(from + pageSize, all.size()));
    }
}
