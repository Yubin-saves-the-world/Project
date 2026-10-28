package com.asdf.board.be.workout.controller;

import com.asdf.board.be.global.enums.TargetPart;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.workout.entity.Exercise;
import com.asdf.board.be.workout.repository.ExerciseRepository;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Tag(name = "workout", description = "운동")
@RestController
@RequestMapping("/api/exercises")
@RequiredArgsConstructor
public class ExerciseController {

    private final ExerciseRepository exerciseRepository;

    @GetMapping
    public Map<String, Object> list(
            @RequestParam(required = false) String target_part,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(name = "page_size", defaultValue = "50") int pageSize,
            @AuthenticationPrincipal Jwt jwt
    ) {
        var pageable = PageRequest.of(page - 1, pageSize);
        var result = target_part != null
                ? exerciseRepository.findByIsActiveTrueAndTargetPartOrderByNameAsc(TargetPart.valueOf(target_part), pageable)
                : exerciseRepository.findByIsActiveTrueOrderByNameAsc(pageable);

        return Map.of(
                "items", result.getContent().stream().map(this::toMap).toList(),
                "page", page,
                "total", result.getTotalElements()
        );
    }

    @GetMapping("/{id}")
    public Map<String, Object> get(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        Exercise ex = exerciseRepository.findById(id)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
        return toMap(ex);
    }

    private Map<String, Object> toMap(Exercise e) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("exercise_id", e.getId());
        m.put("name", e.getName());
        m.put("target_part", e.getTargetPart().name());
        m.put("equipment", e.getEquipment().name());
        m.put("difficulty", e.getDifficulty());
        m.put("description", e.getDescription());
        m.put("media_url", e.getMediaUrl());
        m.put("min_sets", 3);
        m.put("max_sets", 5);
        return m;
    }
}
