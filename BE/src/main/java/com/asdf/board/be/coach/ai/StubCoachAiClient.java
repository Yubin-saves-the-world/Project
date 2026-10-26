package com.asdf.board.be.coach.ai;

import java.util.List;
import java.util.regex.Pattern;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * LLM이 연결되기 전까지 쓰는 개발용 구현. 키워드로만 답을 고르며 의학적 판단은 하지 않는다.
 */
@Slf4j
@Component
public class StubCoachAiClient implements CoachAiClient {

    private static final Pattern PAIN = Pattern.compile("통증|아파|아프|쑤시|저리|부상|다쳤");
    private static final Pattern EASIER = Pattern.compile("쉬운|쉽게|어려|힘들|바꿔|교체|대신");
    private static final Pattern REMOVE = Pattern.compile("빼줘|빼고|빼 |제외|건너뛰|하기 싫");
    private static final String PAIN_NOTICE = " 통증이 있다면 운동을 멈추고 전문의와 상담해 주세요.";

    public StubCoachAiClient() {
        log.warn("[개발용] LLM 대신 StubCoachAiClient를 사용합니다. 답변은 실제 AI가 만든 것이 아닙니다.");
    }

    @Override
    public Reply ask(Context context, String question) {
        boolean pain = PAIN.matcher(question).find();
        StringBuilder reply = new StringBuilder("(개발용 답변) ");
        Proposal proposal = null;

        if (!pain && EASIER.matcher(question).find() && context.todayItems() != null) {
            ItemView target = context.todayItems().stream().filter(i -> i.alternativeExerciseId() != null).findFirst()
                    .orElse(context.todayItems().isEmpty() ? null : context.todayItems().get(0));
            if (target != null) {
                boolean swap = target.alternativeExerciseId() != null;
                int sets = Math.max(2, target.sets() - 1);
                Long exerciseId = swap ? target.alternativeExerciseId() : target.exerciseId();
                proposal = new Proposal(
                        swap ? target.exerciseName() + "을(를) 같은 부위의 다른 종목으로 바꿔요"
                                : target.exerciseName() + " 세트 수를 줄여요",
                        List.of(new Change("replace", target.itemId(), exerciseId, sets, target.reps())));
                reply.append("오늘 루틴의 ").append(target.exerciseName()).append(swap
                        ? "이(가) 부담된다면 같은 부위의 다른 종목으로 바꿔 볼까요?"
                        : "이(가) 부담된다면 세트 수를 줄여 볼까요?");
            }
        } else if (!pain && REMOVE.matcher(question).find() && context.todayItems() != null && context.todayItems().size() > 1) {
            ItemView last = context.todayItems().get(context.todayItems().size() - 1);
            proposal = new Proposal(last.exerciseName() + "을(를) 오늘 루틴에서 빼요",
                    List.of(new Change("remove", last.itemId(), null, null, null)));
            reply.append("오늘은 ").append(last.exerciseName()).append("을(를) 빼고 진행해도 괜찮아요.");
        }
        if (proposal == null) {
            reply.append("최근 7일 동안 ").append(context.workoutsLast7Days()).append("번 운동했어요.");
            if (context.todayRoutineId() == null) {
                reply.append(" 오늘은 예정된 루틴이 없는 휴식일이에요.");
            }
        }
        if (pain) {
            reply.append(PAIN_NOTICE);
        }
        return new Reply(reply.toString(), proposal);
    }
}
