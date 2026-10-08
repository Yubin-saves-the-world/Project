package com.asdf.board.be;

import com.asdf.board.be.body.entity.BodyAnalysis;
import com.asdf.board.be.body.entity.GoalBody;
import com.asdf.board.be.body.entity.Photo;
import com.asdf.board.be.community.entity.Block;
import com.asdf.board.be.community.entity.Post;
import com.asdf.board.be.community.entity.PostLike;
import com.asdf.board.be.global.enums.ExperienceLevel;
import com.asdf.board.be.global.enums.TargetPart;
import com.asdf.board.be.notification.entity.NotificationSetting;
import com.asdf.board.be.user.entity.PasswordResetToken;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.entity.UserConsent;
import com.asdf.board.be.user.entity.UserProfile;
import com.asdf.board.be.workout.entity.Exercise;
import com.asdf.board.be.workout.entity.ExercisePrescription;
import com.asdf.board.be.workout.entity.Routine;
import com.asdf.board.be.workout.entity.RoutineItem;
import com.asdf.board.be.workout.entity.WorkoutLog;
import com.asdf.board.be.workout.entity.WorkoutSet;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceException;
import jakarta.persistence.PersistenceContext;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@Transactional
@EnabledIfEnvironmentVariable(named = "DB_URL", matches = ".+")
class EntityPersistenceTest {

    @PersistenceContext
    EntityManager em;

    private User newUser(String name) {
        String nickname = name + UUID.randomUUID().toString().substring(0, 8);
        User user = User.builder().email(nickname + "@example.com").passwordHash("h".repeat(60)).nickname(nickname).build();
        em.persist(user);
        return user;
    }

    private void flushAndClear() {
        em.flush();
        em.clear();
    }

    @Test
    void user_기본값과_감사_시각이_채워진다() {
        User user = newUser("지한");
        flushAndClear();
        User found = em.find(User.class, user.getId());
        assertThat(found.getRole()).isEqualTo(User.Role.user);
        assertThat(found.getStatus()).isEqualTo(User.Status.active);
        assertThat(found.getAuthProvider()).isEqualTo(User.AuthProvider.email);
        assertThat(found.getCreatedAt()).isNotNull();
        assertThat(found.getUpdatedAt()).isNotNull();
        assertThat(found.getKakaoId()).isNull();
    }

    @Test
    void user_닉네임_중복은_DB가_막는다() {
        User first = newUser("중복");
        User dup = User.builder().email("other-" + UUID.randomUUID() + "@example.com").nickname(first.getNickname()).build();
        assertThatThrownBy(() -> {
            em.persist(dup);
            em.flush();
        }).isInstanceOf(PersistenceException.class);
    }

    @Test
    void 동의_이력과_신체정보가_회원_1명에_여러_행으로_쌓인다() {
        User user = newUser("이력");
        for (UserConsent.ConsentType type : UserConsent.ConsentType.values()) {
            em.persist(UserConsent.builder().user(user).consentType(type).agreed(true).policyVersion("2026-10-01")
                    .source(UserConsent.Source.signup).build());
        }
        for (int w = 68; w <= 70; w++) {
            em.persist(UserProfile.builder().user(user).heightCm(new BigDecimal("174.0")).weightKg(new BigDecimal(w + ".5"))
                    .age(18).goalType(UserProfile.GoalType.muscle).weeklyFrequency(4).experienceLevel(ExperienceLevel.under3m).build());
        }
        flushAndClear();
        Long consents = em.createQuery("select count(c) from UserConsent c where c.user.id = :id", Long.class).setParameter("id", user.getId()).getSingleResult();
        Long profiles = em.createQuery("select count(p) from UserProfile p where p.user.id = :id", Long.class).setParameter("id", user.getId()).getSingleResult();
        assertThat(consents).isEqualTo(4);
        assertThat(profiles).isEqualTo(3);
        UserProfile latest = em.createQuery("select p from UserProfile p where p.user.id = :id order by p.id desc", UserProfile.class)
                .setParameter("id", user.getId()).setMaxResults(1).getSingleResult();
        assertThat(latest.getWeightKg()).isEqualByComparingTo("70.5");
        assertThat(latest.getGender()).isEqualTo(UserProfile.Gender.none);
        assertThat(latest.getMeasuredAt()).isNotNull();
    }

    @Test
    void 신체정보_범위를_벗어나면_CHECK가_막는다() {
        User user = newUser("범위");
        UserProfile bad = UserProfile.builder().user(user).heightCm(new BigDecimal("50.0")).weightKg(new BigDecimal("60.0")).age(18)
                .goalType(UserProfile.GoalType.diet).weeklyFrequency(3).experienceLevel(ExperienceLevel.over1y).build();
        assertThatThrownBy(() -> {
            em.persist(bad);
            em.flush();
        }).isInstanceOf(PersistenceException.class);
    }

    @Test
    void 분석_JSON과_계산_컬럼이_저장된다() {
        User user = newUser("분석");
        Photo photo = Photo.builder().user(user).type(Photo.Type.current).storageKey("photos/1/" + UUID.randomUUID() + ".jpg")
                .contentType("image/jpeg").sizeBytes(123456).build();
        em.persist(photo);
        BodyAnalysis analysis = BodyAnalysis.builder().user(user).photo(photo)
                .judgementsJson("[{\"item\":\"shoulder\",\"level\":\"caution\"}]")
                .unavailableJson("[{\"key\":\"neck_forward\",\"reason\":\"SIDE_PHOTO_MISSING\"}]")
                .shoulderTiltDeg(new BigDecimal("3.2")).build();
        em.persist(analysis);
        flushAndClear();
        BodyAnalysis found = em.find(BodyAnalysis.class, analysis.getId());
        assertThat(found.getStatus()).isEqualTo(BodyAnalysis.Status.pending);
        assertThat(found.getSource()).isEqualTo(BodyAnalysis.Source.photo);
        assertThat(found.getPendingKey()).isEqualTo(1);
        assertThat(found.getBalanceScore()).isNull();
        assertThat(found.getJudgementsJson()).contains("shoulder").contains("caution");
        assertThat(found.getPhoto().getContentType()).isEqualTo("image/jpeg");
        assertThat(found.getPhoto().getExpiresAt()).isNull();
    }

    @Test
    void 사용자당_pending_분석은_1건만_허용한다() {
        User user = newUser("대기");
        em.persist(BodyAnalysis.builder().user(user).build());
        em.flush();
        BodyAnalysis second = BodyAnalysis.builder().user(user).build();
        assertThatThrownBy(() -> {
            em.persist(second);
            em.flush();
        }).isInstanceOf(PersistenceException.class);
    }

    @Test
    void 목표_체형은_사용자당_1개다() {
        User user = newUser("목표");
        em.persist(GoalBody.builder().user(user).status(GoalBody.Status.done).description("어깨가 넓은 몸").build());
        em.flush();
        GoalBody second = GoalBody.builder().user(user).status(GoalBody.Status.done).description("또 하나").build();
        assertThatThrownBy(() -> {
            em.persist(second);
            em.flush();
        }).isInstanceOf(PersistenceException.class);
    }

    @Test
    void 운동_종목의_이름_검색용_계산_컬럼과_복합키가_동작한다() {
        Exercise ex = Exercise.builder().name("테스트 스쿼트").targetPart(TargetPart.leg).equipment(Exercise.Equipment.barbell).difficulty(3).build();
        em.persist(ex);
        em.persist(ExercisePrescription.builder().exercise(ex).experienceLevel(ExperienceLevel.under3m).minSets(3).maxSets(4).build());
        em.persist(ExercisePrescription.builder().exercise(ex).experienceLevel(ExperienceLevel.over1y).minSets(4).maxSets(6).build());
        flushAndClear();
        Exercise found = em.find(Exercise.class, ex.getId());
        assertThat(found.getNameNospace()).isEqualTo("테스트스쿼트");
        assertThat(found.getIsActive()).isTrue();
        ExercisePrescription.Key key = new ExercisePrescription.Key();
        key.setExerciseId(ex.getId());
        key.setExperienceLevel(ExperienceLevel.over1y);
        ExercisePrescription p = em.find(ExercisePrescription.class, key);
        assertThat(p.getMaxSets()).isEqualTo(6);
        assertThat(p.getExercise().getName()).isEqualTo("테스트 스쿼트");
    }

    @Test
    void 같은_종목의_진행중_운동은_1개만_허용하고_세트는_client_set_id로_중복을_막는다() {
        User user = newUser("운동");
        Exercise ex = Exercise.builder().name("테스트 데드리프트").targetPart(TargetPart.back).equipment(Exercise.Equipment.barbell).difficulty(4).build();
        em.persist(ex);
        Routine routine = Routine.builder().user(user).analysis(null).scheduledDate(LocalDate.of(2026, 10, 7)).title("등 집중")
                .targetPart(TargetPart.back).estimatedMinutes(45).build();
        BodyAnalysis analysis = BodyAnalysis.builder().user(user).build();
        em.persist(analysis);
        routine.setAnalysis(analysis);
        em.persist(routine);
        em.persist(RoutineItem.builder().routine(routine).exercise(ex).orderNo(1).targetSets(4).targetReps(8)
                .targetWeightKg(new BigDecimal("60.0")).build());
        WorkoutLog log = WorkoutLog.builder().user(user).exercise(ex).routine(routine).workoutDate(LocalDate.of(2026, 10, 7))
                .startedAt(LocalDateTime.of(2026, 10, 7, 18, 0)).build();
        em.persist(log);
        String clientSetId = UUID.randomUUID().toString();
        em.persist(WorkoutSet.builder().log(log).clientSetId(clientSetId).setNo(1).weightKg(new BigDecimal("60.0")).reps(8).build());
        flushAndClear();
        WorkoutLog found = em.find(WorkoutLog.class, log.getId());
        assertThat(found.getStatus()).isEqualTo(WorkoutLog.Status.in_progress);
        assertThat(found.getActiveExerciseId()).isEqualTo(ex.getId());
        WorkoutSet set = em.createQuery("select s from WorkoutSet s where s.log.id = :id", WorkoutSet.class).setParameter("id", log.getId()).getSingleResult();
        assertThat(set.getClientSetId()).isEqualTo(clientSetId);
        assertThat(set.getVersion()).isEqualTo(1);
        assertThat(set.getIsDone()).isTrue();

        WorkoutLog second = WorkoutLog.builder().user(em.getReference(User.class, user.getId())).exercise(em.getReference(Exercise.class, ex.getId()))
                .workoutDate(LocalDate.of(2026, 10, 7)).startedAt(LocalDateTime.of(2026, 10, 7, 19, 0)).build();
        assertThatThrownBy(() -> {
            em.persist(second);
            em.flush();
        }).isInstanceOf(PersistenceException.class);
    }

    @Test
    void 좋아요_차단_알림설정_복합키가_저장된다() {
        User a = newUser("에이");
        User b = newUser("비");
        Post post = Post.builder().user(a).category(Post.Category.info).title("제목").content("본문").build();
        em.persist(post);
        em.persist(PostLike.builder().post(post).user(b).build());
        em.persist(Block.builder().blocker(a).blocked(b).build());
        em.persist(NotificationSetting.builder().user(a).type(NotificationSetting.Type.workout).notifyTime(LocalTime.of(18, 30)).build());
        flushAndClear();
        PostLike.Key likeKey = new PostLike.Key();
        likeKey.setPostId(post.getId());
        likeKey.setUserId(b.getId());
        assertThat(em.find(PostLike.class, likeKey)).isNotNull();
        Post found = em.find(Post.class, post.getId());
        assertThat(found.getLikeCount()).isZero();
        assertThat(found.getIsPinned()).isFalse();
        Block.Key blockKey = new Block.Key();
        blockKey.setBlockerId(a.getId());
        blockKey.setBlockedId(b.getId());
        assertThat(em.find(Block.class, blockKey).getCreatedAt()).isNotNull();
        NotificationSetting.Key nKey = new NotificationSetting.Key();
        nKey.setUserId(a.getId());
        nKey.setType(NotificationSetting.Type.workout);
        NotificationSetting n = em.find(NotificationSetting.class, nKey);
        assertThat(n.getEnabled()).isTrue();
        assertThat(n.getNotifyTime()).isEqualTo(LocalTime.of(18, 30));
    }

    @Test
    void 비밀번호_재설정_토큰은_해시만_저장한다() {
        User user = newUser("토큰");
        String hash = "a".repeat(64);
        em.persist(PasswordResetToken.builder().user(user).tokenHash(hash).expiresAt(LocalDateTime.now().plusMinutes(30)).build());
        flushAndClear();
        String saved = em.createQuery("select t.tokenHash from PasswordResetToken t where t.user.id = :id", String.class)
                .setParameter("id", user.getId()).getSingleResult();
        assertThat(saved).isEqualTo(hash);
    }
}
