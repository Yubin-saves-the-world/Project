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
    public TokenResponse login(LoginRequest request) {
        User user = userRepository.findByEmail(request.email())
                .filter(found -> found.getStatus() == User.Status.active && found.getPasswordHash() != null)
                .orElse(null);

        String storedHash = user != null ? user.getPasswordHash() : unknownUserHash;
        boolean matches = passwordEncoder.matches(request.password(), storedHash);
        if (user == null || !matches) {
            throw new ApiException(ErrorCode.INVALID_CREDENTIALS);
        }

        TokenService.IssuedToken token = tokenService.issue(user);
        boolean onboardingCompleted = userProfileRepository.existsByUserId(user.getId());
        return TokenResponse.bearer(token.value(), token.expiresInSeconds(), onboardingCompleted);
    }
}
