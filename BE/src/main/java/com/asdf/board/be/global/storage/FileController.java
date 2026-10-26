package com.asdf.board.be.global.storage;

import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import io.swagger.v3.oas.annotations.Hidden;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import java.time.Duration;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Hidden
@RestController
@RequestMapping("/api/files")
@RequiredArgsConstructor
public class FileController {

    private final PhotoStorage storage;
    private final SignedUrls signedUrls;

    @SecurityRequirements
    @GetMapping("/{key}")
    public ResponseEntity<byte[]> get(
            @PathVariable String key, @RequestParam long exp, @RequestParam String sig) {
        if (!signedUrls.valid(key, exp, sig)) {
            throw new ApiException(ErrorCode.NOT_FOUND);
        }
        byte[] data = storage.get(key);
        MediaType type = key.endsWith(".png") ? MediaType.IMAGE_PNG : MediaType.IMAGE_JPEG;
        return ResponseEntity.ok()
                .contentType(type)
                .cacheControl(CacheControl.maxAge(Duration.ofMinutes(5)).cachePrivate())
                .body(data);
    }
}
