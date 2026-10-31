package com.asdf.board.be.body.integration;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.asdf.board.be.global.exception.ApiException;
import com.asdf.board.be.user.entity.User;
import com.asdf.board.be.user.entity.UserConsent;
import com.asdf.board.be.user.repository.*;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.ExecutorService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;
import org.springframework.web.multipart.MultipartFile;
import tools.jackson.databind.ObjectMapper;

class BodyIntegrationServiceTest {
  @TempDir Path storage;

  @Test
  void deniesUnknownAccountBeforeReadingUpload() throws Exception {
    var users = mock(UserRepository.class);
    var file = mock(MultipartFile.class);
    var service =
        service(users, mock(UserProfileRepository.class), mock(UserConsentRepository.class));
    assertThatThrownBy(() -> service.upload(9, file, "current", "front"))
        .isInstanceOf(ApiException.class);
    verifyNoInteractions(file);
  }

  @Test
  void malformedImageHeaderIsValidationFailureAndLeavesNoFile() throws Exception {
    var users = mock(UserRepository.class);
    var user = mock(User.class);
    when(user.getStatus()).thenReturn(User.Status.active);
    when(users.findById(9L)).thenReturn(Optional.of(user));
    var profiles = mock(UserProfileRepository.class);
    when(profiles.existsByUserId(9L)).thenReturn(true);
    var consents = mock(UserConsentRepository.class);
    var consent = mock(UserConsent.class);
    when(consent.getConsentType()).thenReturn(UserConsent.ConsentType.body_photo);
    when(consent.getAgreed()).thenReturn(true);
    when(consents.findByUserIdOrderByIdAsc(9L)).thenReturn(List.of(consent));
    var file = mock(MultipartFile.class);
    when(file.getSize()).thenReturn(5L);
    when(file.getBytes()).thenReturn(new byte[] {(byte) 255, (byte) 216, (byte) 255, 0, 0});
    assertThatThrownBy(() -> service(users, profiles, consents).upload(9, file, "current", "front"))
        .isInstanceOf(ApiException.class);
    try (var files = java.nio.file.Files.list(storage)) {
      assertThat(files.count()).isZero();
    }
  }

  private BodyIntegrationService service(
      UserRepository users, UserProfileRepository profiles, UserConsentRepository consents)
      throws Exception {
    var manager = mock(PlatformTransactionManager.class);
    when(manager.getTransaction(any())).thenReturn(new SimpleTransactionStatus());
    return new BodyIntegrationService(
        mock(PhotoRepository.class),
        mock(AnalysisRepository.class),
        users,
        profiles,
        consents,
        new ObjectMapper(),
        manager,
        mock(ExecutorService.class),
        storage.toString(),
        "http://127.0.0.1:8001",
        "http://127.0.0.1:8080",
        "test-only-key");
  }
}
