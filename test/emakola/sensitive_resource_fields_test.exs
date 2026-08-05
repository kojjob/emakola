defmodule Emakola.SensitiveResourceFieldsTest do
  use ExUnit.Case, async: true

  @sensitive_fields %{
    Emakola.Notifications.DeviceToken => [:token],
    Emakola.Payments.Payment => [:gateway_response],
    Emakola.Payments.PaymentSplit => [:subaccount_code],
    Emakola.Payments.Payout => [
      :recipient_code,
      :transfer_code,
      :transfer_reference,
      :gateway_response
    ],
    Emakola.Stores.StorePayoutAccount => [:subaccount_code, :payout_destination],
    Emakola.Stores.StoreVerification => [:id_number, :id_document_key, :business_doc_key],
    Emakola.Suppliers.PartnerCreditOffer => [:creditor_subaccount_code],
    Emakola.Suppliers.Supplier => [:payment_details],
    Emakola.Webhooks.OutboundWebhook => [:secret],
    Emakola.Webhooks.WebhookDelivery => [:payload, :response_body, :error]
  }

  test "persisted credentials and high-risk personal data are private and sensitive" do
    for {resource, fields} <- @sensitive_fields,
        field <- fields do
      attribute = Ash.Resource.Info.attribute(resource, field)

      refute attribute.public?, "#{inspect(resource)}.#{field} must not be public"
      assert attribute.sensitive?, "#{inspect(resource)}.#{field} must be sensitive"
    end
  end

  test "device registration still accepts a token without exposing the token attribute" do
    assert Ash.Resource.Info.action_input?(
             Emakola.Notifications.DeviceToken,
             :register,
             :token
           )

    token_argument =
      Emakola.Notifications.DeviceToken
      |> Ash.Resource.Info.action(:register)
      |> Map.fetch!(:arguments)
      |> Enum.find(&(&1.name == :token))

    assert token_argument.public?
    assert token_argument.sensitive?
  end
end
