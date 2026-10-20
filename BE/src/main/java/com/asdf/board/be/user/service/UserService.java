package com.asdf.board.be.user.service;

import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.user.dto.SignupRequest;
import com.asdf.board.be.user.dto.UserCreatedResponse;
import com.asdf.board.be.user.dto.UserMeResponse;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.entity.UserConsent;
import com.asdf.board.be.user.repository.UserConsentRepository;
import com.asdf.board.be.user.repository.UserProfileRepository;
import com.asdf.board.be.user.repository.UserRepository;
import java.util.Arrays;
import java.util.EnumMap;
import java.util.Map;
import java.util.List;
import jakarta.persistence.EntityManager;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final UserConsentRepository userConsentRepository;
    private final UserProfileRepository userProfileRepository;
    private final PasswordEncoder passwordEncoder;
    private final EntityManager entityManager;

    @Value("${vitality.policy-version}")
    private String currentPolicyVersion;

    @Transactional
    public UserCreatedResponse signup(SignupRequest request) {

        // 사용자가 필수 이용약관을 동의하였는지 확인(allConsentsAgreed)
        // ! = 동의하지 않았으면 가입을 막고 TERMS_REQUIRED 에러를 발생 시킨다.
        if (!request.allConsentsAgreed()) {
            throw new ApiException(ErrorCode.TERMS_REQUIRED);
        }

        // 이메일 중복 검사 
        // request.email()가 코드가 이메일을 가져온다.
        // userRepository 안에 존재하면 EMAIL_DUPLICATED 에러를 발생시킨다.
        if (userRepository.existsByEmail(request.email())) {
            throw new ApiException(ErrorCode.EMAIL_DUPLICATED);
        }
        // 닉네임 중복 검사
        // request.nickname()가 닉네임을 가져온다.
        // userRepository안에 존재하면 NICKNAME_DUPLICATED 에러를 발생시킨다.
        if (userRepository.existsByNickname(request.nickname())) {
            throw new ApiException(ErrorCode.NICKNAME_DUPLICATED);
        }

        // 유저 객체를 만든 뒤 비밀번호를 암호화한 뒤 데이터베이스에 저장한다.
        User user = userRepository.save(User.builder()
                .email(request.email())
                .passwordHash(passwordEncoder.encode(request.password()))
                // 위 코드가 비밀번호를 암호화 시킨다.
                .nickname(request.nickname())
                .build());

        // DB에 즉시 반영하고, 방금 생성된 유저 데이터를 동기화 한다.
        entityManager.flush();
        // 메모리에 임시로 쌓여있던 변경 내용들을 DB에 즉시 넣어 동기화
        entityManager.refresh(user);
        // 자바 메모리에 있는 객체의 상태를 불러와 새로고침 하는 코드

        String policyVersion = request.policyVersion() != null ? request.policyVersion() : currentPolicyVersion;
        List<UserConsent> consents = Arrays.stream(UserConsent.ConsentType.values())
                .map(type -> UserConsent.builder()
                        .user(user)
                        .consentType(type)
                        .agreed(true)
                        .policyVersion(policyVersion)
                        .source(UserConsent.Source.signup)
                        .build())
                .toList();
        userConsentRepository.saveAll(consents);

        // 가입 완료된 유저 정보를 응답 DTO로 변환하여 반환한다.
        return UserCreatedResponse.from(user);
    }

    @Transactional(readOnly = true)
    public UserMeResponse getMe(Long userId) {
        // ID로 유저를 조회하고, 없으면 인증 에러를 발생시킨다.
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));

        Map<UserConsent.ConsentType, Boolean> current = new EnumMap<>(UserConsent.ConsentType.class);
        userConsentRepository.findByUserIdOrderByIdAsc(userId)
                .forEach(consent -> current.put(consent.getConsentType(), consent.getAgreed()));

        // 모든 필수 약관에 빠짐없이 동의했는지 확인한다.
        // 약관 종류 = ConsentType.values()를 하나씩 가져와 유저가 저장한 동의 내역 = current에서 true인지 확인
        boolean consentCompleted = Arrays.stream(UserConsent.ConsentType.values())
                .allMatch(type -> Boolean.TRUE.equals(current.get(type)));

        // 유저 정보, 프로필 등록 여부, 약관 동의 상태 등을 모아서 응답으로 반환합니다.
        // user = 조회한 유저의 기본 정보 (이메일, 닉네임 등)
        // userProfileRepository.existsByUserId(userId) 유저가 프로필을 등록했는지 여부 (true 또는 false)
        // consentCompleted : 위에서 계산한 모든 약관 동의
        return UserMeResponse.of(
                user,
                userProfileRepository.existsByUserId(userId),
                consentCompleted,
                Boolean.TRUE.equals(current.get(UserConsent.ConsentType.body_photo)),
                Boolean.TRUE.equals(current.get(UserConsent.ConsentType.ai_processing)));
    }
}
