defmodule EmakolaWeb.AuthComponents do
  @moduledoc "Shared inputs for phone (WhatsApp/SMS) authentication."
  use Phoenix.Component

  attr :id, :string, required: true
  attr :name, :string, default: "otp[code]"

  def otp_code_input(assigns) do
    ~H"""
    <input
      type="text"
      id={@id}
      name={@name}
      inputmode="numeric"
      autocomplete="one-time-code"
      pattern="[0-9]{6}"
      maxlength="6"
      placeholder="123456"
      required
      class="w-full bg-white border border-gray-200 rounded-xl px-4 py-3 text-center text-lg tracking-[0.5em] text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
    />
    """
  end

  attr :id, :string, required: true
  attr :name, :string, default: "phone[number]"
  attr :cc_name, :string, default: "phone[cc]"

  def phone_input(assigns) do
    ~H"""
    <div class="flex gap-2">
      <select
        name={@cc_name}
        class="w-24 bg-white border border-gray-200 rounded-xl px-2 py-3 text-sm text-[#0c1526]"
      >
        <option value="+233">+233</option>
        <option value="+234">+234</option>
      </select>
      <input
        type="tel"
        id={@id}
        name={@name}
        inputmode="tel"
        autocomplete="tel-national"
        placeholder="50 123 4567"
        required
        class="flex-1 bg-white border border-gray-200 rounded-xl px-4 py-3 text-sm text-[#0c1526] placeholder:text-[#8896ab] focus:ring-2 focus:ring-[#2563eb] focus:border-[#2563eb] transition-colors"
      />
    </div>
    """
  end

  attr :href, :string, required: true
  attr :class, :string, default: nil

  def whatsapp_button(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={[
        "w-full flex items-center justify-center gap-2 bg-whatsapp hover:bg-whatsapp-dark text-white font-semibold py-3 rounded-xl text-sm transition-all active:scale-[0.98] shadow-sm",
        @class
      ]}
    >
      <span class="material-symbols-outlined text-xl">chat</span> Continue with WhatsApp
    </.link>
    """
  end
end
