package com.asdf.board.be.global.security;

import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.repository.UserRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.core.convert.converter.Converter;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.InvalidBearerTokenException;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class JwtAuthenticationConverter implements Converter<Jwt, AbstractAuthenticationToken> {

    private final UserRepository userRepository;

    @Override
    public AbstractAuthenticationToken convert(Jwt jwt) {
        User user = findUser(jwt.getSubject());
        if (user.getStatus() != User.Status.active) {
            throw new InvalidBearerTokenException("탈퇴한 회원입니다.");
        }
        return new JwtAuthenticationToken(
                jwt,
                List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole().name().toUpperCase())),
                jwt.getSubject());
    }

    private User findUser(String subject) {
        try {
            return userRepository.findById(Long.valueOf(subject))
                    .orElseThrow(() -> new InvalidBearerTokenException("존재하지 않는 회원입니다."));
        } catch (NumberFormatException e) {
            throw new InvalidBearerTokenException("토큰 형식이 올바르지 않습니다.");
        }
    }
}
