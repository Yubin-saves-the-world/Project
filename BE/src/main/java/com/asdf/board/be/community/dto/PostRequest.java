package com.asdf.board.be.community.dto;

import java.util.List;

public record PostRequest(
        String category,
        String title,
        String content,
        List<Long> removeImageIds
) {}
