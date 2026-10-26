package com.asdf.board.be.global.storage;

import com.asdf.board.be.global.config.VitalityProperties;
import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.global.exception.ErrorCode;
import java.io.IOException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

@Component
@RequiredArgsConstructor
public class ImageFiles {

    public record Image(byte[] data, String extension) {
        public String contentType() {
            return ".png".equals(extension) ? "image/png" : "image/jpeg";
        }
    }

    private final VitalityProperties properties;

    public Image read(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        byte[] data;
        try {
            data = file.getBytes();
        } catch (IOException e) {
            throw new ApiException(ErrorCode.VALIDATION_FAILED);
        }
        if (data.length > properties.photo().maxBytes()) {
            throw new ApiException(ErrorCode.IMAGE_TOO_LARGE);
        }
        return new Image(data, detectExtension(data));
    }

    private static String detectExtension(byte[] data) {
        if (data.length >= 3 && (data[0] & 0xFF) == 0xFF && (data[1] & 0xFF) == 0xD8 && (data[2] & 0xFF) == 0xFF) {
            return ".jpg";
        }
        if (data.length >= 8 && (data[0] & 0xFF) == 0x89 && data[1] == 'P' && data[2] == 'N' && data[3] == 'G'
                && data[4] == 0x0D && data[5] == 0x0A && data[6] == 0x1A && data[7] == 0x0A) {
            return ".png";
        }
        throw new ApiException(ErrorCode.IMAGE_INVALID_TYPE);
    }
}
