package com.asdf.board.be.body.controller;

import com.asdf.board.be.body.entity.BodyAnalysis;
import com.asdf.board.be.body.entity.GoalBody;
import com.asdf.board.be.body.entity.Photo;
import com.asdf.board.be.body.repository.BodyAnalysisRepository;
import com.asdf.board.be.body.repository.GoalBodyRepository;
import com.asdf.board.be.body.repository.PhotoRepository;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.enums.TargetPart;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.repository.UserRepository;
import com.asdf.board.be.workout.entity.*;
import com.asdf.board.be.workout.repository.*;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;

@Tag(name = "body", description = "체형 분석")
@RestController
@RequestMapping("/api/body-analyses")
@RequiredArgsConstructor
@Transactional
public class BodyAnalysisController {

    private final BodyAnalysisRepository analysisRepository;
    private final GoalBodyRepository goalBodyRepository;
    private final PhotoRepository photoRepository;
    private final UserRepository userRepository;
    private final RoutineRepository routineRepository;
    private final RoutineItemRepository routineItemRepository;
    private final ExerciseRepository exerciseRepository;

    private Long userId(Jwt jwt) { return Long.valueOf(jwt.getSubject()); }
    private User user(Jwt jwt) {
        return userRepository.findById(userId(jwt)).orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
    }

    @GetMapping
    public Map<String, Object> list(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(name = "page_size", defaultValue = "20") int pageSize,
            @AuthenticationPrincipal Jwt jwt
    ) {
        var pageable = PageRequest.of(page - 1, pageSize);
        var result = analysisRepository.findByUserIdOrderByCreatedAtDesc(userId(jwt), pageable);
        return Map.of(
                "items", result.getContent().stream().map(this::toSummary).toList(),
                "page", page,
                "total", result.getTotalElements()
        );
    }

    @GetMapping("/usage")
    public Map<String, Object> usage(@AuthenticationPrincipal Jwt jwt) {
        int limit = 5;
        LocalDateTime resetAt = LocalDateTime.now().withDayOfMonth(1).plusMonths(1).withHour(0).withMinute(0).withSecond(0);
        int used = analysisRepository.countByUserIdAndCreatedAtAfter(userId(jwt),
                LocalDateTime.now().withDayOfMonth(1).withHour(0).withMinute(0).withSecond(0));
        return Map.of(
                "used", used,
                "limit", limit,
                "remaining", Math.max(0, limit - used),
                "reset_at", resetAt.toString()
        );
    }

    @GetMapping("/{id}")
    public Map<String, Object> detail(@PathVariable Long id, @AuthenticationPrincipal Jwt jwt) {
        BodyAnalysis a = analysisRepository.findById(id)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
        if (!a.getUser().getId().equals(userId(jwt))) throw new ApiException(ErrorCode.FORBIDDEN);
        return toDetail(a);
    }

    @PostMapping("/text")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> startTextAnalysis(@RequestBody Map<String, Object> body, @AuthenticationPrincipal Jwt jwt) {
        User u = user(jwt);
        String text = (String) body.get("text");
        if (text == null || text.isBlank()) throw new ApiException(ErrorCode.VALIDATION_FAILED);
        Long goalId = body.get("goal_body_id") != null ? Long.valueOf(body.get("goal_body_id").toString()) : null;
        GoalBody goal = goalId != null ? goalBodyRepository.findById(goalId).orElse(null) : null;

        BodyAnalysis analysis = BodyAnalysis.builder()
                .user(u)
                .source(BodyAnalysis.Source.text)
                .status(BodyAnalysis.Status.done)
                .goalBody(goal)
                .textInput(text)
                .balanceScore(70)
                .bodyType("분석 중")
                .textSummary(text.length() > 100 ? text.substring(0, 100) + "..." : text)
                .completedAt(LocalDateTime.now())
                .build();
        analysis = analysisRepository.save(analysis);
        return Map.of("analysis_id", analysis.getId());
    }

    @PostMapping("/photo")
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> startPhotoAnalysis(@RequestBody Map<String, Object> body, @AuthenticationPrincipal Jwt jwt) {
        User u = user(jwt);
        Long photoId = Long.valueOf(body.get("photo_id").toString());
        Photo photo = photoRepository.findById(photoId).orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));

        Long goalId = body.get("goal_body_id") != null ? Long.valueOf(body.get("goal_body_id").toString()) : null;
        GoalBody goal = goalId != null ? goalBodyRepository.findById(goalId).orElse(null) : null;

        BodyAnalysis analysis = BodyAnalysis.builder()
                .user(u)
                .source(BodyAnalysis.Source.photo)
                .status(BodyAnalysis.Status.done)
                .photo(photo)
                .goalBody(goal)
                .balanceScore(75)
                .bodyType("균형형")
                .textSummary("전반적으로 균형 잡힌 체형입니다.")
                .completedAt(LocalDateTime.now())
                .build();
        analysis = analysisRepository.save(analysis);
        return Map.of("analysis_id", analysis.getId());
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> generateRoutines(@RequestBody Map<String, Object> body, @AuthenticationPrincipal Jwt jwt) {
        User u = user(jwt);
        Long analysisId = Long.valueOf(body.get("analysis_id").toString());
        BodyAnalysis analysis = analysisRepository.findById(analysisId)
                .orElseThrow(() -> new ApiException(ErrorCode.NOT_FOUND));
        if (!analysis.getUser().getId().equals(userId(jwt))) throw new ApiException(ErrorCode.FORBIDDEN);

        List<Exercise> exercises = exerciseRepository.findByIsActiveTrueOrderByNameAsc(PageRequest.of(0, 10))
                .getContent();
        if (exercises.isEmpty()) throw new ApiException(ErrorCode.INTERNAL_ERROR);

        TargetPart[] parts = TargetPart.values();
        List<Map<String, Object>> routines = new ArrayList<>();
        LocalDate today = LocalDate.now();

        for (int i = 0; i < Math.min(7, parts.length); i++) {
            LocalDate date = today.plusDays(i);
            if (routineRepository.findByUserIdAndScheduledDate(u.getId(), date).isPresent()) continue;

            TargetPart part = parts[i % parts.length];
            Routine r = Routine.builder()
                    .user(u)
                    .analysis(analysis)
                    .scheduledDate(date)
                    .title(partLabel(part) + " 강화 루틴")
                    .targetPart(part)
                    .estimatedMinutes(40)
                    .build();
            r = routineRepository.save(r);

            List<Exercise> partExercises = exercises.stream()
                    .filter(e -> e.getTargetPart() == part)
                    .limit(4)
                    .toList();
            if (partExercises.isEmpty()) partExercises = exercises.subList(0, Math.min(4, exercises.size()));

            for (int j = 0; j < partExercises.size(); j++) {
                routineItemRepository.save(RoutineItem.builder()
                        .routine(r)
                        .exercise(partExercises.get(j))
                        .orderNo(j + 1)
                        .targetSets(3)
                        .targetReps(10)
                        .reason(partLabel(part) + " 강화에 효과적인 운동이에요.")
                        .build());
            }

            List<RoutineItem> items = routineItemRepository.findByRoutineIdOrderByOrderNoAsc(r.getId());
            Map<String, Object> routineMap = new LinkedHashMap<>();
            routineMap.put("routine_id", r.getId());
            routineMap.put("title", r.getTitle());
            routineMap.put("scheduled_date", r.getScheduledDate().toString());
            routineMap.put("items", items.stream().map(it -> Map.of("exercise", Map.of("name", it.getExercise().getName()))).toList());
            routines.add(routineMap);
        }

        return Map.of("routines", routines);
    }

    private String partLabel(TargetPart part) {
        return switch (part) {
            case chest -> "가슴";
            case back -> "등";
            case leg -> "하체";
            case shoulder -> "어깨";
            case arm -> "팔";
            case core -> "코어";
        };
    }

    private Map<String, Object> toSummary(BodyAnalysis a) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("analysis_id", a.getId());
        m.put("status", a.getStatus().name());
        m.put("created_at", a.getCreatedAt().toString());
        m.put("balance_score", a.getBalanceScore());
        m.put("body_type", a.getBodyType());
        return m;
    }

    private Map<String, Object> toDetail(BodyAnalysis a) {
        Map<String, Object> m = new LinkedHashMap<>(toSummary(a));
        m.put("text_summary", a.getTextSummary());
        m.put("comparison_summary", a.getComparisonSummary());
        m.put("completed_at", a.getCompletedAt() != null ? a.getCompletedAt().toString() : null);
        return m;
    }
}
