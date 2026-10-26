package com.asdf.board.be.user.controller;

import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.user.dto.AllergyDto;
import com.asdf.board.be.user.dto.AllergyListDto;
import com.asdf.board.be.user.dto.AllergyRequest;
import com.asdf.board.be.user.service.AllergyService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "profile", description = "신체정보 · 설문")
@RestController
@RequestMapping("/api/users/me/allergies")
@RequiredArgsConstructor
public class AllergyController {

    private final AllergyService allergyService;

    @Operation(summary = "알레르기·기피 음식 목록")
    @GetMapping
    public AllergyListDto list(@AuthenticationPrincipal Jwt jwt) {
        return allergyService.list(CurrentUser.id(jwt));
    }

    @Operation(summary = "알레르기·기피 음식 추가", description = "공백을 제거한 뒤 같은 문자열이면 중복. 사용자당 최대 50개이며 넘기면 VALIDATION_FAILED.")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AllergyDto create(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody AllergyRequest request) {
        return allergyService.create(CurrentUser.id(jwt), request);
    }

    @Operation(summary = "알레르기·기피 음식 삭제")
    @DeleteMapping("/{allergyId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable("allergyId") Long allergyId) {
        allergyService.delete(CurrentUser.id(jwt), allergyId);
    }
}
