package com.asdf.board.be.auth.service;

import com.asdf.board.be.auth.dto.LoginRequest;
import com.asdf.board.be.auth.dto.TokenResponse;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import com.asdf.board.be.global.security.TokenService;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.repository.UserProfileRepository;
import com.asdf.board.be.user.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final UserProfileRepository userProfileRepository;
    private final PasswordEncoder passwordEncoder;
    private final TokenService tokenService;
    private final String unknownUserHash;

    public AuthService(
            UserRepository userRepository,
            UserProfileRepository userProfileRepository,
            PasswordEncoder passwordEncoder,
            TokenService tokenService) {
        this.userRepository = userRepository;
        this.userProfileRepository = userProfileRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenService = tokenService;
        this.unknownUserHash = passwordEncoder.encode("unknown-user-placeholder");
    }

    @Transactional(readOnly = true)
    public TokenResponse refresh(Long userId) {
        User user = userRepository.findById(userId)
                .filter(u -> u.getStatus() == User.Status.active)
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED));
        TokenService.IssuedToken token = tokenService.issue(user);
        boolean onboardingCompleted = userProfileRepository.existsByUserId(user.getId());
        return TokenResponse.bearer(token.value(), token.expiresInSeconds(), onboardingCompleted);
    }

    @Transactional(readOnly = true)
    public TokenResponse login(LoginRequest request) {
        // 이메일로 유저를 조회하고, 활성화 상태이며 비밀번호가 존재하는지 확인
        User user = userRepository.findByEmail(request.email()) // 데이터베이스에서 유저를 찾는다
                .filter(found -> found.getStatus() == User.Status.active && found.getPasswordHash() != null)
                // 찾은 유저가 활성화(active)로 되어있고, 비밀번호 해시가 존재하는지 검증한다.
                .orElse(null);
                // 조건이 안 맞거나 없으면 null 처리

        // 유저가 없으면 타이밍 공격 방지용 가짜 해시를 사용하여 비밀번호 일치 여부를 검증한다.
        String storedHash = user != null ? user.getPasswordHash() : unknownUserHash;
        boolean matches = passwordEncoder.matches(request.password(), storedHash);
        if (user == null || !matches) { // 유저가 없거나 비밀번호가 틀렸다면
            throw new ApiException(ErrorCode.INVALID_CREDENTIALS);
            // INVALID_CREDENTIALS 에러를 발생하여 로그인 차단
        }

        // 인증에 성공하면 토큰을 발급, 프로필 등록 여부를 확인한 뒤 토큰 응답을 반환한다.
        TokenService.IssuedToken token = tokenService.issue(user);
        // tokenService.issue : 로그인 인증 토큰 발급
        boolean onboardingCompleted = userProfileRepository.existsByUserId(user.getId());
        // 유저가 프로필 정보를 등록했는지 여부(existsByUserId) 확인
        return TokenResponse.bearer(token.value(), token.expiresInSeconds(), onboardingCompleted);
        // 토큰 값, 프로필 등록 여부를 담아 클라이언트에게 응답(TokenResponse.bearer) 한다.
    }
}
