package com.asdf.board.be.body.controller;

import com.asdf.board.be.body.dto.AnalysisAcceptedDto;
import com.asdf.board.be.body.dto.AnalysisDto;
import com.asdf.board.be.body.dto.AnalysisPageDto;
import com.asdf.board.be.body.dto.AnalysisRequest;
import com.asdf.board.be.body.dto.AnalysisUsageDto;
import com.asdf.board.be.body.dto.TextAnalysisRequest;
import com.asdf.board.be.body.service.AnalysisService;
import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.global.web.PageParams;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "analysis", description = "체형 분석")
@Validated
@RestController
@RequestMapping("/api/body-analyses")
@RequiredArgsConstructor
public class BodyAnalysisController {

    private final AnalysisService analysisService;

    @Operation(summary = "사진 체형 분석 요청", description = "비동기. 즉시 202와 analysis_id를 돌려주고 앱이 2초마다 결과를 조회합니다. 서버는 90초가 지난 pending을 failed(AI_TIMEOUT)로 바꿉니다.")
    @PostMapping("/photo")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public AnalysisAcceptedDto request(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody AnalysisRequest request) {
        return analysisService.request(CurrentUser.id(jwt), request);
    }

    @Operation(summary = "글 체형 분석 요청", description = "글에서는 각도·비율을 추정하지 않습니다. 결과는 source=text, text_summary만 채워지고 하루 분석 한도를 사진 분석과 함께 셉니다.")
    @PostMapping("/text")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public AnalysisAcceptedDto requestText(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody TextAnalysisRequest request) {
        return analysisService.requestText(CurrentUser.id(jwt), request);
    }

    @Operation(summary = "분석 남은 횟수", description = "오늘 사용한 횟수는 done·pending만 셉니다. 초기화는 KST 자정.")
    @GetMapping("/usage")
    public AnalysisUsageDto usage(@AuthenticationPrincipal Jwt jwt) {
        return analysisService.usage(CurrentUser.id(jwt));
    }

    @Operation(summary = "분석 기록 목록", description = "최신순.")
    @GetMapping
    public AnalysisPageDto list(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return analysisService.list(CurrentUser.id(jwt), page, pageSize);
    }

    @Operation(summary = "분석 결과 조회", description = "pending이면 결과 필드는 null입니다. failed도 HTTP 에러가 아니라 200이며 error_code·error_message를 보여줍니다.")
    @GetMapping("/{analysisId}")
    public AnalysisDto get(@AuthenticationPrincipal Jwt jwt, @PathVariable("analysisId") Long analysisId) {
        return analysisService.get(CurrentUser.id(jwt), analysisId);
    }
}
