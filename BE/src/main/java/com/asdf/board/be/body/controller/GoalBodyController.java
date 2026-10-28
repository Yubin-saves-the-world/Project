package com.asdf.board.be.body.controller;

import com.asdf.board.be.body.entity.GoalBody;
import com.asdf.board.be.body.repository.GoalBodyRepository;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.repository.UserRepository;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

@Tag(name = "body", description = "체형 분석")
@RestController
@RequestMapping("/api/goal-bodies")
@RequiredArgsConstructor
@Transactional
public class GoalBodyController {

    private final GoalBodyRepository goalBodyRepository;
    private final UserRepository userRepository;

    @GetMapping
    public Map<String, Object> get(@AuthenticationPrincipal Jwt jwt) {
        Long userId = Long.valueOf(jwt.getSubject());
        return goalBodyRepository.findTopByUserIdOrderByCreatedAtDesc(userId)
                .map(this::toMap)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> create(@RequestBody Map<String, Object> body, @AuthenticationPrincipal Jwt jwt) {
        Long userId = Long.valueOf(jwt.getSubject());
        User user = userRepository.findById(userId).orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
        String description = (String) body.get("description");
        GoalBody goal = GoalBody.builder()
                .user(user)
                .status(GoalBody.Status.done)
                .description(description)
                .summary("목표 체형: " + (description != null ? description : ""))
                .build();
        return toMap(goalBodyRepository.save(goal));
    }

    @PatchMapping("/{id}")
    public Map<String, Object> update(@PathVariable Long id, @RequestBody Map<String, Object> body, @AuthenticationPrincipal Jwt jwt) {
        Long userId = Long.valueOf(jwt.getSubject());
        GoalBody goal = goalBodyRepository.findById(id).orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
        if (!goal.getUser().getId().equals(userId)) throw new ApiException(ErrorCode.FORBIDDEN);
        if (body.containsKey("description")) goal.setDescription((String) body.get("description"));
        return toMap(goalBodyRepository.save(goal));
    }

    private Map<String, Object> toMap(GoalBody g) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("goal_body_id", g.getId());
        m.put("status", g.getStatus().name());
        m.put("description", g.getDescription());
        m.put("summary", g.getSummary());
        return m;
    }
}
