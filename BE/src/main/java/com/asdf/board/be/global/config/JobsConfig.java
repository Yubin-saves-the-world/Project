package com.asdf.board.be.global.config;

import com.asdf.board.be.body.service.AnalysisService;
import com.asdf.board.be.body.service.GoalBodyService;
import com.asdf.board.be.body.service.PhotoService;
import com.asdf.board.be.workout.service.WorkoutService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;

@Slf4j
@Configuration
@EnableScheduling
@RequiredArgsConstructor
@ConditionalOnProperty(name = "vitality.jobs.enabled", havingValue = "true", matchIfMissing = true)
public class JobsConfig {

    private final AnalysisService analysisService;
    private final GoalBodyService goalBodyService;
    private final PhotoService photoService;
    private final WorkoutService workoutService;

    @Scheduled(fixedDelay = 15_000, initialDelay = 15_000)
    public void failStuckWork() {
        int analyses = analysisService.failTimedOut();
        int goals = goalBodyService.failTimedOut();
        if (analyses + goals > 0) {
            log.warn("90초 넘게 끝나지 않은 AI 작업을 실패 처리했습니다. analyses={} goals={}", analyses, goals);
        }
    }

    @Scheduled(fixedDelay = 300_000, initialDelay = 60_000)
    public void removeExpiredGoalPhotos() {
        int removed = photoService.removeExpiredGoalPhotos();
        if (removed > 0) {
            log.info("등록되지 않은 목표 사진 {}장을 삭제했습니다.", removed);
        }
    }

    @Scheduled(fixedDelay = 600_000, initialDelay = 120_000)
    public void abortStaleWorkouts() {
        int aborted = workoutService.abortStale();
        if (aborted > 0) {
            log.info("6시간 넘게 끝나지 않은 운동 기록 {}건을 중단 처리했습니다.", aborted);
        }
    }
}
