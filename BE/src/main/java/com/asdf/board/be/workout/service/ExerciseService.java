package com.asdf.board.be.workout.service;

import com.asdf.board.be.global.web.Texts;
import com.asdf.board.be.global.enums.ExperienceLevel;
import com.asdf.board.be.global.enums.TargetPart;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.web.PageParams;
import com.asdf.board.be.user.entity.UserProfile;
import com.asdf.board.be.user.repository.UserProfileRepository;
import com.asdf.board.be.user.service.AccessGuard;
import com.asdf.board.be.workout.dto.ExerciseDetailDto;
import com.asdf.board.be.workout.dto.ExercisePageDto;
import com.asdf.board.be.workout.dto.ExerciseSummaryDto;
import com.asdf.board.be.workout.entity.Exercise;
import com.asdf.board.be.workout.entity.ExercisePrescription;
import com.asdf.board.be.workout.repository.ExercisePrescriptionRepository;
import com.asdf.board.be.workout.repository.ExerciseRepository;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ExerciseService {

    private final ExerciseRepository exerciseRepository;
    private final ExercisePrescriptionRepository prescriptionRepository;
    private final UserProfileRepository profileRepository;
    private final AccessGuard accessGuard;

    @Transactional(readOnly = true)
    public ExercisePageDto list(
            Long userId, TargetPart part, Integer difficulty, Exercise.Equipment equipment, String q,
            int page, int pageSize) {
        accessGuard.requireOnboarded(userId);
        String keyword = q == null ? "" : Texts.compact(q).toLowerCase(Locale.ROOT);
        Specification<Exercise> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.isTrue(root.get("isActive")));
            if (part != null) {
                predicates.add(cb.equal(root.get("targetPart"), part));
            }
            if (equipment != null) {
                predicates.add(cb.equal(root.get("equipment"), equipment));
            }
            if (difficulty != null) {
                predicates.add(cb.le(root.get("difficulty"), difficulty));
            }
            if (!keyword.isEmpty()) {
                predicates.add(cb.like(cb.lower(root.get("nameNospace")), "%" + keyword + "%"));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
        Page<Exercise> result = exerciseRepository.findAll(
                spec, PageParams.of(page, pageSize, Sort.by(Sort.Direction.ASC, "name")));
        ExperienceLevel level = experience(userId);
        Map<Long, ExercisePrescription> prescriptions = prescriptions(
                result.getContent().stream().map(Exercise::getId).toList(), level);
        List<ExerciseSummaryDto> items = result.getContent().stream()
                .map(e -> summary(e, prescriptions.get(e.getId()))).toList();
        return new ExercisePageDto(items, page, pageSize, (int) result.getTotalElements());
    }

    @Transactional(readOnly = true)
    public ExerciseDetailDto get(Long userId, Long exerciseId) {
        accessGuard.requireOnboarded(userId);
        Exercise exercise = exerciseRepository.findById(exerciseId)
                .filter(Exercise::getIsActive)
                .orElseThrow(ApiException.of(ErrorCode.NOT_FOUND));
        ExerciseSummaryDto s = summary(exercise, prescriptions(List.of(exerciseId), experience(userId)).get(exerciseId));
        return new ExerciseDetailDto(s.exerciseId(), s.name(), s.targetPart(), s.equipment(), s.difficulty(),
                s.minSets(), s.maxSets(), s.mediaUrl(), exercise.getDescription() == null ? "" : exercise.getDescription());
    }

    public ExerciseDetailDto detailOf(Exercise exercise) {
        ExerciseSummaryDto s = summary(exercise,
                prescriptions(List.of(exercise.getId()), ExperienceLevel.under3m).get(exercise.getId()));
        return new ExerciseDetailDto(s.exerciseId(), s.name(), s.targetPart(), s.equipment(), s.difficulty(),
                s.minSets(), s.maxSets(), s.mediaUrl(), exercise.getDescription() == null ? "" : exercise.getDescription());
    }

    public ExperienceLevel experience(Long userId) {
        return profileRepository.findFirstByUserIdOrderByIdDesc(userId)
                .map(UserProfile::getExperienceLevel).orElse(ExperienceLevel.under3m);
    }

    public Map<Long, ExercisePrescription> prescriptions(Collection<Long> ids, ExperienceLevel level) {
        Map<Long, ExercisePrescription> result = new HashMap<>();
        if (!ids.isEmpty()) {
            prescriptionRepository.findByIdExerciseIdInAndIdExperienceLevel(ids, level)
                    .forEach(p -> result.put(p.getId().getExerciseId(), p));
        }
        return result;
    }

    public static ExerciseSummaryDto summary(Exercise e, ExercisePrescription p) {
        return new ExerciseSummaryDto(
                e.getId(), e.getName(), e.getTargetPart().name(), e.getEquipment().name(), e.getDifficulty(),
                p == null ? 2 : p.getMinSets(), p == null ? 4 : p.getMaxSets(), e.getMediaUrl());
    }
}
