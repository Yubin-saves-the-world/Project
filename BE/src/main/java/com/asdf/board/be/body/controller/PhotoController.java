package com.asdf.board.be.body.controller;

import com.asdf.board.be.body.dto.DeletedCountDto;
import com.asdf.board.be.body.dto.PhotoDto;
import com.asdf.board.be.body.dto.PhotoPageDto;
import com.asdf.board.be.body.entity.Photo;
import com.asdf.board.be.body.service.PhotoService;
import com.asdf.board.be.global.web.CurrentUser;
import com.asdf.board.be.global.web.PageParams;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@Tag(name = "photos", description = "사진")
@Validated
@RestController
@RequestMapping("/api/photos")
@RequiredArgsConstructor
public class PhotoController {

    private final PhotoService photoService;

    @Operation(summary = "사진 업로드", description = "JPG·PNG, 10MB 이하. 사용자당 최대 20장. 목표 사진(type=goal)은 1시간 안에 목표 체형으로 등록하지 않으면 삭제됩니다.")
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public PhotoDto upload(
            @AuthenticationPrincipal Jwt jwt,
            @RequestPart("image") MultipartFile image,
            @RequestParam("type") Photo.Type type,
            @RequestParam(value = "side", required = false) Photo.Side side) {
        return photoService.upload(CurrentUser.id(jwt), image, type, side);
    }

    @Operation(summary = "사진 목록", description = "최신순. 각 항목의 url은 조회 시점에 새로 발급합니다.")
    @GetMapping
    public PhotoPageDto list(
            @AuthenticationPrincipal Jwt jwt,
            @RequestParam(value = "type", required = false) Photo.Type type,
            @RequestParam(value = "page", defaultValue = "1") @Min(value = 1, message = "page는 1 이상이어야 합니다.") int page,
            @RequestParam(value = "page_size", defaultValue = "20")
            @Min(value = 1, message = "page_size는 1 이상이어야 합니다.")
            @Max(value = PageParams.MAX_SIZE, message = "page_size는 50 이하여야 합니다.") int pageSize) {
        return photoService.list(CurrentUser.id(jwt), type, page, pageSize);
    }

    @Operation(summary = "사진 전체 삭제", description = "분석 중인 목표 체형이 쓰는 사진은 건너뛰고 skipped_count로 알려줍니다.")
    @DeleteMapping
    public DeletedCountDto deleteAll(@AuthenticationPrincipal Jwt jwt, @RequestParam("type") Photo.Type type) {
        return photoService.deleteAll(CurrentUser.id(jwt), type);
    }

    @Operation(summary = "사진 삭제", description = "원본 파일도 함께 삭제합니다. 이 사진을 쓴 분석 결과는 남고 photo_id만 null이 됩니다.")
    @DeleteMapping("/{photoId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal Jwt jwt, @PathVariable("photoId") Long photoId) {
        photoService.delete(CurrentUser.id(jwt), photoId);
    }
}
