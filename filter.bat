0<0# : ^
''' 
@python %~f0 %* 
@goto :eof
'''

import tkinter as tk
from tkinter import ttk 
import tkinter.messagebox
import tkinter.filedialog
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg, NavigationToolbar2Tk
from matplotlib.figure import Figure
from matplotlib import pyplot
import numpy
from scipy import signal, fft

# main window
win = tk.Tk()
# data values
data=None

# main window
validate_float=win.register(lambda v: (v:=v.replace('.','',1))=='' or (v:=v[1:] if v[0]=='-' else v)=='' or v.isdigit())
validate_int=win.register(lambda v:  v=='' or (v:=v[1:] if v[0]=='-' else v)=='' or v.isdigit())
win.geometry('+%d+100'%((win.winfo_screenwidth()-900)/2))
win.title('Data Filter')
control_bar=tk.Frame(win)
control_bar.pack(side='left', anchor='n', fill='y', expand=True)
btn_trim=tk.Button(control_bar, text="Trim/Invert", state="disabled", command=lambda : trim())
btn_trim.pack(side='top', anchor='s', fill='x', pady=(0, 5))
btn_fft=tk.Button(control_bar, text="FFT", state="disabled", command=lambda : plot_fft())
btn_fft.pack(side='top', anchor='s', fill='x', pady=(0, 5))
btn_filter_iir=tk.Button(control_bar, text="Filter (IIR)", command=lambda : filter_iir())
btn_filter_iir.pack(side='top', anchor='s', fill='x', pady=(0, 5))
btn_filter_fir=tk.Button(control_bar, text="Filter (FIR)", command=lambda : filter_fir())
btn_filter_fir.pack(side='top', anchor='s', fill='x', pady=(0, 5))
tkvar_msg=tk.StringVar(value='')
tk.Label(control_bar, textvariable=tkvar_msg, anchor='nw', justify='left', wraplength=150).pack(side='top', anchor='nw', fill='y', expand=True)
win.protocol("WM_DELETE_WINDOW", lambda: pyplot.close('all') is win.destroy())

# matplotlib plot in tk
def on_scroll(evt):
	if thread is None and (axe:=evt.inaxes) is not None and (evt.button=='up' or evt.button=='down'):
		xmin,xmax=axe.get_xlim()
		ymin,ymax=axe.get_ylim()
		scale=0.9 if evt.button=='up' else 1.1
		axe.set(xlim=(evt.xdata-(evt.xdata-xmin)*scale, evt.xdata+(xmax-evt.xdata)*scale),
		            ylim=(evt.ydata-(evt.ydata-ymin)*scale, evt.ydata+(ymax-evt.ydata)*scale))
		evt.canvas.draw_idle()
figure=Figure(figsize=(6, 5), dpi=100)
figure.subplots_adjust(left=0.2, top=0.95, right=0.95)
canvas=FigureCanvasTkAgg(figure, master=win)
canvas.get_tk_widget().pack(side='top', anchor='ne', fill='x', expand=True)
canvas.mpl_connect('scroll_event', on_scroll)
navbar=NavigationToolbar2Tk(canvas, win, pack_toolbar=False)
tk.Frame(navbar, bd=1, width=2, highlightthickness=0, relief='groove').pack(side='left', anchor='w', padx=5, pady=3, fill='y')
btn_load=tk.Button(navbar, text="Load Data", command=lambda : load())
btn_load.pack(side='left')
btn_save=tk.Button(navbar, text="SAVE DATA", state="disabled", command=lambda : save())
btn_save.pack(side='left')
navbar.update()
navbar.pack(side='bottom', anchor='nw', fill='x')
axe1=figure.add_subplot(111) # only 1 plot in 1x1 table now

# when 'load' button clicked, load data from file
def load():
	global data
	try:
		if (file:=tk.filedialog.askopenfilename(title='Load Data File', defaultextension='.txt', filetypes=[('Text','*.txt'),('All files','*')])):
			data=numpy.loadtxt(file, dtype=numpy.float64)
			btn_save['state']='normal' if len(data)>0 else 'disabled'
			btn_trim['state']='normal' if len(data)>0 else 'disabled'
			btn_fft['state']='normal' if len(data)>0 else 'disabled'
			plot()
	except Exception as e:
		tk.messagebox.showerror(title='Error', message=e)
	
#when 'save' button clicked
def save():
	try:
		if (file:=tk.filedialog.asksaveasfile(title='Save Data File', defaultextension='.txt', filetypes=[('Text','*.txt'),('All files','*')])):
			with file:
				for t in data:
					file.write(str(t)+'\n')
	except Exception as e:
		tk.messagebox.showerror(title='Error', message=e)

# wait for complete and render the canvas
_last_draw=None
def plot():
	axe1.cla()
	axe1.set_ylabel("Data Value")
	axe1.set_xlabel("Points : Total "+str(len(data)))
	axe1.grid(True)
	global _last_draw
	if _last_draw is not None:
		_last_draw.remove()
	_last_draw, =axe1.plot(data, color='orange', linewidth=1)
	canvas.draw_idle()
	navbar.update()
	navbar.push_current() 

#when trim button is clicked
def trim():
	def _trim():
		global data
		try:
			h=ctrl_head.get().strip()
			t=ctrl_tail.get().strip()
			h=0 if h=='' else max(0, min(len(data)-1, int(h)))
			t=len(data) if t=='' else min(max(int(t)+1, h+1), len(data))
			invt=var_invt.get()
		except ValueError as e:
			tk.messagebox.showerror(title='Error', message=e, parent=dlg)
		else:
			if h>0 or t<len(data):
				data=data[h:t]
			if invt:
				data=data*-1.0
			plot()
			dlg.destroy()
	dlg=tk.Toplevel(win)
	wingeo=win.geometry().split('+')
	dlg.geometry('+'+str(int(wingeo[1])+250)+'+'+str(int(wingeo[2])+200))
	dlg.grab_set()
	dlg.title('Trim')
	tbl=tk.Frame(dlg)
	tbl.pack(side='top', fill='x', padx=10, pady=10, ipadx=10)
	tk.Label(tbl, anchor='e', text='   Keep data from index').grid(row=0, column=0, sticky='we')
	ctrl_head=tk.Entry(tbl, width=5, validate='key', validatecommand=(validate_int,'%P'))
	ctrl_head.grid(row=0, column=1, sticky='we')
	tk.Label(tbl, anchor='e', text='   Keep data to index').grid(row=1, column=0, sticky='we')
	ctrl_tail=tk.Entry(tbl, width=5, validate='key', validatecommand=(validate_int,'%P'))
	ctrl_tail.grid(row=1, column=1, sticky='we')
	tk.Label(tbl, anchor='e', text='   Invert').grid(row=2, column=0, sticky='we')
	var_invt=tk.BooleanVar(value=False)
	tk.Checkbutton(tbl, variable=var_invt, onvalue=True, offvalue=False).grid(row=2, column=1, sticky='w')
	tk.Button(dlg, text="  OK  ", command=_trim).pack(side='right', padx=5, anchor='n', pady=5)
	tk.Button(dlg, text="CANCEL", command=dlg.destroy).pack(side='right', anchor='n', pady=5)

#plot fft
def plot_fft():
	pyplot.close('all')
	yf = fft.rfft(data)
	xf = fft.rfftfreq(len(data), 1)
	fig, ax1=pyplot.subplots()
	fig.subplots_adjust(right=0.85)
	ax1.set_title('FFT')
	ax1.set_xlabel('Freq. ')
	ax1.set_ylabel('Amplitude')
	ax1.grid()
	ax1.plot(xf, numpy.abs(yf), linewidth=1, color='orange')
	pyplot.show()

#when 'Filter (IIR)' button is clicked
def filter_iir():
	sr=1
	def dofilter():
		global data
		try:
			b=tuple(float(t.strip()) for t in var_coef_b.get().split(','))
			a=tuple(float(t.strip()) for t in var_coef_a.get().split(','))
			data=signal.filtfilt(b, a, data)
			plot()
			dlg.destroy()
		except Exception as e:
			tk.messagebox.showerror(title='Error', message=e, parent=dlg)
	def show_freq():
		try:
			b=tuple(float(t.strip()) for t in var_coef_b.get().split(','))
			a=tuple(float(t.strip()) for t in var_coef_a.get().split(','))
			w,h=signal.freqz(b, a, worN=250, fs=sr)
			pyplot.close('all')
			fig, ax1=pyplot.subplots()
			fig.subplots_adjust(right=0.85)
			ax1.set_title('Filter frequency response')
			ax1.set_xlabel('Freq. (Hz)')
			ax1.set_ylabel('Response', color='blue')
			ax1.grid()
			ax1.plot(w, numpy.abs(h), linewidth=1, color='blue')
			ax2=ax1.twinx()
			ax2.set_ylabel('Phase (degree)', color='orange')
			ax2.plot(w, numpy.unwrap(numpy.angle(h))*180/3.141592653589793, linewidth=1, color='orange')
			pyplot.show()
		except Exception as e:
			tk.messagebox.showerror(title='Error', message=e, parent=dlg)
	def choose_bessel():
		try:
			type=('lowpass','highpass','bandpass','bandstop')[ctrl_bessel_type.current()]
			order=int(ctrl_bessel_order.get().strip())
			freqs=tuple(float(f.strip()) for f in ctrl_bessel_freq.get().split(','))
			for f in freqs:
				assert f<sr/2 and f>0.0, f'frequency must be in (0,{sr/2})'
			b,a=signal.bessel(order, freqs, type, fs=sr)
			var_coef_b.set(','.join(str(x) for x in b))
			var_coef_a.set(','.join(str(x) for x in a))
		except Exception as e:
			tk.messagebox.showerror(title='Error', message=e, parent=dlg)
	def choose_butt():
		try:
			type=('lowpass','highpass','bandpass','bandstop')[ctrl_butt_type.current()]
			order=int(ctrl_butt_order.get().strip())
			freqs=tuple(float(f.strip()) for f in ctrl_butt_freq.get().split(','))
			for f in freqs:
				assert f<sr/2 and f>0.0, f'frequency must be in (0,{sr/2})'
			b,a=signal.butter(order, freqs, type, fs=sr)
			var_coef_b.set(','.join(str(x) for x in b))
			var_coef_a.set(','.join(str(x) for x in a))
		except Exception as e:
			tk.messagebox.showerror(title='Error', message=e, parent=dlg)
	def choose_cheby1():
		try:
			type=('lowpass','highpass','bandpass','bandstop')[ctrl_cheby1_type.current()]
			order=int(ctrl_cheby1_order.get().strip())
			ripple=int(ctrl_cheby1_ripple.get().strip())
			freqs=tuple(float(f.strip()) for f in ctrl_cheby1_freq.get().split(','))
			for f in freqs:
				assert f<sr/2 and f>0.0, f'frequency must be in (0,{sr/2})'
			b,a=signal.cheby1(order, ripple, freqs, type, fs=sr)
			var_coef_b.set(','.join(str(x) for x in b))
			var_coef_a.set(','.join(str(x) for x in a))
		except Exception as e:
			tk.messagebox.showerror(title='Error', message=e, parent=dlg)
	def choose_cheby2():
		try:
			type=('lowpass','highpass','bandpass','bandstop')[ctrl_cheby2_type.current()]
			order=int(ctrl_cheby2_order.get().strip())
			attenuation=float(ctrl_cheby2_attenuation.get().strip())
			freqs=tuple(float(f.strip()) for f in ctrl_cheby2_freq.get().split(','))
			for f in freqs:
				assert f<sr/2 and f>0.0, f'frequency must be in (0,{sr/2})'
			b,a=signal.cheby2(order, attenuation, freqs, type, fs=sr)
			var_coef_b.set(','.join(str(x) for x in b))
			var_coef_a.set(','.join(str(x) for x in a))
		except Exception as e:
			tk.messagebox.showerror(title='Error', message=e, parent=dlg)			
	def choose_npc():
		try:
			type=ctrl_npc_type.current()
			assert type>=0 and type<=3
			q=float(ctrl_npc_q.get().strip())
			f=float(ctrl_npc_freq.get().strip())
			assert f<sr/2 and f>0.0, f'frequency must be in (0,{sr/2})'
			if type==0:
				b,a=signal.iirnotch(f, q, fs=sr)
			elif type==1:
				b,a=signal.iirpeak(f, q, fs=sr)
			elif type==2:
				b,a=signal.iircomb(f, q, ftype='notch', fs=sr)
			elif type==3:
				b,a=signal.iircomb(f, q, ftype='peak', fs=sr)
			var_coef_b.set(','.join(str(x) for x in b))
			var_coef_a.set(','.join(str(x) for x in a))
		except Exception as e:
			tk.messagebox.showerror(title='Error', message=e, parent=dlg)			
	dlg=tk.Toplevel(win)
	wingeo=win.geometry().split('+')
	dlg.geometry('+'+str(int(wingeo[1])+50)+'+'+str(int(wingeo[2])+50))
	dlg.grab_set()
	dlg.title('Filter')
	tk.Label(dlg, justify='left', text='''\
Choose filter needed with right parameters for it, to generation the appropriate coefficients,
then click 'OK' button. the coefficients are ',' separated, and the Z-domain transfer function is :
	Y(z)/X(z)=(b[0]+b[1]/z+b[2]/z^2+...)/(a[0]+a[1]/z+a[2]/z^2...)
''').pack(side='top', anchor='w')
	tbl_gen=tk.Frame(dlg)
	tbl_gen.pack(side='top', fill='x', ipadx=5, ipady=5)
	irow=0
	tk.Label(tbl_gen, text='Bessel/Thomson : for Band-Pass/Band-Stop, input 2 Freq. separated by ","').grid(columnspan=9, row=irow, column=0, sticky='w')
	tk.Label(tbl_gen, anchor='w', text='Type :').grid(row=(irow:=irow+1), column=0, sticky='we')
	ctrl_bessel_type=ttk.Combobox(tbl_gen, justify='left', values=('Low-Pass','High-Pass','Band-Pass','Band-Stop'), state='readonly')
	ctrl_bessel_type.current(0)
	ctrl_bessel_type.grid(row=irow, column=1, sticky='we')
	tk.Label(tbl_gen, anchor='e', text='  Freq. : ').grid(row=irow, column=2, sticky='we')
	ctrl_bessel_freq=tk.Entry(tbl_gen, width=10)
	ctrl_bessel_freq.grid(row=irow, column=3, sticky='w')
	tk.Label(tbl_gen, anchor='e', text='  Order : ').grid(row=irow, column=4, sticky='we')
	ctrl_bessel_order=tk.Entry(tbl_gen, width=5, validate='key', validatecommand=(validate_int,'%P'))
	ctrl_bessel_order.grid(row=irow, column=5, sticky='w')
	tk.Button(tbl_gen, text="CHOOSE", command=choose_bessel).grid(row=irow, column=8, padx=5, sticky='e')
	tk.Label(tbl_gen, text='Butterworth : for Band-Pass/Band-Stop, input 2 Freq. separated by ","').grid(columnspan=9, row=(irow:=irow+1), column=0, sticky='w')
	tk.Label(tbl_gen, anchor='w', text='Type :').grid(row=(irow:=irow+1), column=0, sticky='we')
	ctrl_butt_type=ttk.Combobox(tbl_gen, justify='left', values=('Low-Pass','High-Pass','Band-Pass','Band-Stop'), state='readonly')
	ctrl_butt_type.current(0)
	ctrl_butt_type.grid(row=irow, column=1, sticky='we')
	tk.Label(tbl_gen, anchor='e', text='  Freq. : ').grid(row=irow, column=2, sticky='we')
	ctrl_butt_freq=tk.Entry(tbl_gen, width=10)
	ctrl_butt_freq.grid(row=irow, column=3, sticky='w')
	tk.Label(tbl_gen, anchor='e', text='  Order : ').grid(row=irow, column=4, sticky='we')
	ctrl_butt_order=tk.Entry(tbl_gen, width=5, validate='key', validatecommand=(validate_int,'%P'))
	ctrl_butt_order.grid(row=irow, column=5, sticky='w')
	tk.Button(tbl_gen, text="CHOOSE", command=choose_butt).grid(row=irow, column=8, padx=5, sticky='e')
	tk.Label(tbl_gen, text='Chebyshev I : for Band-Pass/Band-Stop, input 2 Freq. separated by ","').grid(columnspan=9, row=(irow:=irow+1), column=0, sticky='w')
	tk.Label(tbl_gen, anchor='w', text='Type :').grid(row=(irow:=irow+1), column=0, sticky='we')
	ctrl_cheby1_type=ttk.Combobox(tbl_gen, justify='left', values=('Low-Pass','High-Pass','Band-Pass','Band-Stop'), state='readonly')
	ctrl_cheby1_type.current(0)
	ctrl_cheby1_type.grid(row=irow, column=1, sticky='we')
	tk.Label(tbl_gen, anchor='e', text='  Freq. : ').grid(row=irow, column=2, sticky='we')
	ctrl_cheby1_freq=tk.Entry(tbl_gen, width=10)
	ctrl_cheby1_freq.grid(row=irow, column=3, sticky='w')
	tk.Label(tbl_gen, anchor='e', text='  Order : ').grid(row=irow, column=4, sticky='we')
	ctrl_cheby1_order=tk.Entry(tbl_gen, width=5, validate='key', validatecommand=(validate_int,'%P'))
	ctrl_cheby1_order.grid(row=irow, column=5, sticky='w')
	tk.Label(tbl_gen, anchor='e', text=' Number of Ripples : ').grid(row=irow, column=6, sticky='we')
	ctrl_cheby1_ripple=tk.Entry(tbl_gen, width=5, validate='key', validatecommand=(validate_int,'%P'))
	ctrl_cheby1_ripple.grid(row=irow, column=7, sticky='w')
	tk.Button(tbl_gen, text="CHOOSE", command=choose_cheby1).grid(row=irow, column=8, padx=5, sticky='e')	
	tk.Label(tbl_gen, text='Chebyshev II : for Band-Pass/Band-Stop, input 2 Freq. separated by ","').grid(columnspan=9, row=(irow:=irow+1), column=0, sticky='w')
	tk.Label(tbl_gen, anchor='w', text='Type :').grid(row=(irow:=irow+1), column=0, sticky='we')
	ctrl_cheby2_type=ttk.Combobox(tbl_gen, justify='left', values=('Low-Pass','High-Pass','Band-Pass','Band-Stop'), state='readonly')
	ctrl_cheby2_type.current(0)
	ctrl_cheby2_type.grid(row=irow, column=1, sticky='we')
	tk.Label(tbl_gen, anchor='e', text='  Freq. : ').grid(row=irow, column=2, sticky='we')
	ctrl_cheby2_freq=tk.Entry(tbl_gen, width=10)
	ctrl_cheby2_freq.grid(row=irow, column=3, sticky='w')
	tk.Label(tbl_gen, anchor='e', text='  Order : ').grid(row=irow, column=4, sticky='we')
	ctrl_cheby2_order=tk.Entry(tbl_gen, width=5, validate='key', validatecommand=(validate_int,'%P'))
	ctrl_cheby2_order.grid(row=irow, column=5, sticky='w')
	tk.Label(tbl_gen, anchor='e', text='  Attenuation (dB) : ').grid(row=irow, column=6, sticky='we')
	ctrl_cheby2_attenuation=tk.Entry(tbl_gen, width=5, validate='key', validatecommand=(validate_float,'%P'))
	ctrl_cheby2_attenuation.grid(row=irow, column=7, sticky='w')
	tk.Button(tbl_gen, text="CHOOSE", command=choose_cheby2).grid(row=irow, column=8, padx=5, sticky='e')	
	tk.Label(tbl_gen, text='Notch/Peak/Comb : Q=Freq/Bandwidth(-3dB)').grid(columnspan=9, row=(irow:=irow+1), column=0, sticky='w')
	tk.Label(tbl_gen, anchor='w', text='Type :').grid(row=(irow:=irow+1), column=0, sticky='we')
	ctrl_npc_type=ttk.Combobox(tbl_gen, justify='left', values=('Notch','Peak','Comb-Notch','Comb-Peak'), state='readonly')
	ctrl_npc_type.current(0)
	ctrl_npc_type.grid(row=irow, column=1, sticky='we')
	tk.Label(tbl_gen, anchor='e', text='  Freq. : ').grid(row=irow, column=2, sticky='we')
	ctrl_npc_freq=tk.Entry(tbl_gen, width=10,  validate='key', validatecommand=(validate_float,'%P'))
	ctrl_npc_freq.grid(row=irow, column=3, sticky='w')
	tk.Label(tbl_gen, anchor='e', text='  Q value : ').grid(row=irow, column=4, sticky='we')
	ctrl_npc_q=tk.Entry(tbl_gen, width=5, validate='key', validatecommand=(validate_float,'%P'))
	ctrl_npc_q.grid(row=irow, column=5, sticky='w')
	tk.Button(tbl_gen, text="CHOOSE", command=choose_npc).grid(row=irow, column=8, padx=5, sticky='e')	
	tbl_coef=ttk.Frame(dlg, padding=(0,10,0,0))
	tbl_coef.pack(side='top', fill='x', ipadx=5, ipady=5)
	var_coef_b=tk.StringVar(value='')
	var_coef_a=tk.StringVar(value='')
	tk.Label(tbl_coef, anchor='w', text='Coef. B :').grid(row=0, column=0, sticky='we')
	tk.Entry(tbl_coef, width=100, textvariable=var_coef_b).grid(row=0, column=1, sticky='we')
	tk.Label(tbl_coef, anchor='w', text='Coef. A :').grid(row=1, column=0, sticky='we')
	tk.Entry(tbl_coef, width=100, textvariable=var_coef_a).grid(row=1, column=1, sticky='we')
	btn_ok=tk.Button(dlg, text="  OK  ", command=dofilter)
	btn_ok.pack(side='right', padx=5, anchor='n', pady=5)
	tk.Button(dlg, text="  Show Freq. Response  ", command=show_freq).pack(side='right', padx=(5,0), anchor='n', pady=5)
	tk.Button(dlg, text="CANCEL", command=lambda: pyplot.close('all') is dlg.destroy()).pack(side='right', anchor='n', pady=5)
	global data
	btn_ok['state']='normal' if data is not None and len(data)>0 else 'disabled'
	dlg.protocol("WM_DELETE_WINDOW", lambda: pyplot.close('all') is dlg.destroy())

#when 'Filter (IIR)' button is clicked
def filter_fir():
	sr=1
	def dofilter():
		global data
		try:
			c=tuple(float(t.strip()) for t in var_coef.get().split(','))
			data=signal.filtfilt(c, 1.0, data)
			plot()
			dlg.destroy()
		except Exception as e:
			tk.messagebox.showerror(title='Error', message=e, parent=dlg)
	def show_freq():
		try:
			c=tuple(float(t.strip()) for t in var_coef.get().split(','))
			w,h=signal.freqz(c, 1.0, worN=250, fs=sr)
			pyplot.close('all')
			fig, ax1=pyplot.subplots()
			fig.subplots_adjust(right=0.85)
			ax1.set_title('Filter frequency response')
			ax1.set_xlabel('Freq. (Hz)')
			ax1.set_ylabel('Response', color='blue')
			ax1.grid()
			ax1.plot(w, numpy.abs(h), linewidth=1, color='blue')
			ax2=ax1.twinx()
			ax2.set_ylabel('Phase (degree)', color='orange')
			ax2.plot(w, numpy.unwrap(numpy.angle(h))*180/3.141592653589793, linewidth=1, color='orange')
			pyplot.show()
		except Exception as e:
			tk.messagebox.showerror(title='Error', message=e, parent=dlg)
	def choose_win1a():
		try:
			type=('lowpass','highpass','bandpass','bandstop')[ctrl_win1a_type.current()]
			width=float(ctrl_win1a_width.get().strip())
			assert width<sr/2 and width>0.0, f'width must be in (0,{sr/2})'
			attenuation=float(ctrl_win1a_attenuation.get().strip())
			freqs=tuple(float(f.strip()) for f in ctrl_win1a_freq.get().split(','))
			for f in freqs:
				assert f<sr/2 and f>0.0, f'frequency must be in (0,{sr/2})'
			n, beta =signal.kaiserord(attenuation, width/0.5)
			if type!='lowpass' and n%2==0:
				n=n+1
			c = signal.firwin(n, freqs, window=('kaiser', beta), pass_zero=type, fs=sr)
			var_coef.set(','.join(str(x) for x in c))
		except Exception as e:
			tk.messagebox.showerror(title='Error', message=e, parent=dlg)
	def choose_win1b():
		try:
			type=('lowpass','highpass','bandpass','bandstop')[ctrl_win1b_type.current()]
			order=int(ctrl_win1b_order.get().strip())
			win=ctrl_win1b_win.get()
			freqs=tuple(float(f.strip()) for f in ctrl_win1b_freq.get().split(','))
			for f in freqs:
				assert f<sr/2 and f>0.0, f'frequency must be in (0,{sr/2})'
			c = signal.firwin(order+1, freqs, window=win, pass_zero=type, fs=sr)
			var_coef.set(','.join(str(x) for x in c))
		except Exception as e:
			tk.messagebox.showerror(title='Error', message=e, parent=dlg)
	def choose_win2():
		try:
			order=int(ctrl_win2_order.get().strip())
			win=ctrl_win2_win.get()
			freqs=tuple(float(f.strip()) for f in ctrl_win2_freq.get().split(','))
			for f in freqs:
				assert f<=sr/2 and f>=0.0, f'frequency must be in [0,{sr/2}]'
			gains=tuple(float(f.strip()) for f in ctrl_win2_gain.get().split(','))
			c = signal.firwin2(order+1, freqs, gains, window=win, fs=sr)
			var_coef.set(','.join(str(x) for x in c))
		except Exception as e:
			tk.messagebox.showerror(title='Error', message=e, parent=dlg)
	dlg=tk.Toplevel(win)
	wingeo=win.geometry().split('+')
	dlg.geometry('+'+str(int(wingeo[1])+50)+'+'+str(int(wingeo[2])+50))
	dlg.grab_set()
	dlg.title('Filter')
	tk.Label(dlg, justify='left', text='''\
Choose filter needed with right parameters for it, to generation the appropriate coefficients,
then click 'OK' button. the coefficients are ',' separated, and the Z-domain transfer function is :
	Y(z)/X(z)=c[0]+c[1]/z+c[2]/z^2+...
''').pack(side='top', anchor='w')
	tbl_gen=tk.Frame(dlg)
	tbl_gen.pack(side='top', fill='x', ipadx=5, ipady=5)
	irow=0
	tk.Label(tbl_gen, text='Win 1.a (Kaiser window) : input Freq. (separated by ",") , width and attenuation').grid(columnspan=9, row=irow, column=0, sticky='w')
	tk.Label(tbl_gen, anchor='w', text='Type :').grid(row=(irow:=irow+1), column=0, sticky='we')
	ctrl_win1a_type=ttk.Combobox(tbl_gen, justify='left', values=('Low-Pass','High-Pass','Band-Pass','Band-Stop'), state='readonly')
	ctrl_win1a_type.current(0)
	ctrl_win1a_type.grid(row=irow, column=1, sticky='we')
	tk.Label(tbl_gen, anchor='e', text='Freq :').grid(row=irow, column=2, sticky='we')
	ctrl_win1a_freq=tk.Entry(tbl_gen, width=10)
	ctrl_win1a_freq.grid(row=irow, column=3, sticky='w')
	tk.Label(tbl_gen, anchor='e', text='Width :').grid(row=irow, column=4, sticky='we')
	ctrl_win1a_width=tk.Entry(tbl_gen, width=10)
	ctrl_win1a_width.grid(row=irow, column=5, sticky='w')
	tk.Label(tbl_gen, anchor='e', text='  Attenuation (dB) : ').grid(row=irow, column=6, sticky='we')
	ctrl_win1a_attenuation=tk.Entry(tbl_gen, width=5, validate='key', validatecommand=(validate_float,'%P'))
	ctrl_win1a_attenuation.grid(row=irow, column=7, sticky='w')
	tk.Button(tbl_gen, text="CHOOSE", command=choose_win1a).grid(row=irow, column=8, padx=5, sticky='e')
	tk.Label(tbl_gen, text='Win 1.b : input Freq. (separated by ",") , order (even num. for other than Low-Pass), window').grid(columnspan=9, row=(irow:=irow+1), column=0, sticky='w')
	tk.Label(tbl_gen, anchor='w', text='Type :').grid(row=(irow:=irow+1), column=0, sticky='we')
	ctrl_win1b_type=ttk.Combobox(tbl_gen, justify='left', values=('Low-Pass','High-Pass','Band-Pass','Band-Stop'), state='readonly')
	ctrl_win1b_type.current(0)
	ctrl_win1b_type.grid(row=irow, column=1, sticky='we')
	tk.Label(tbl_gen, anchor='e', text='Freq :').grid(row=irow, column=2, sticky='we')
	ctrl_win1b_freq=tk.Entry(tbl_gen, width=10)
	ctrl_win1b_freq.grid(row=irow, column=3, sticky='w')
	tk.Label(tbl_gen, anchor='e', text='Order :').grid(row=irow, column=4, sticky='we')
	ctrl_win1b_order=tk.Entry(tbl_gen, width=10)
	ctrl_win1b_order.grid(row=irow, column=5, sticky='w')
	tk.Label(tbl_gen, anchor='e', text=' Window : ').grid(row=irow, column=6, sticky='we')
	ctrl_win1b_win=ttk.Combobox(tbl_gen, justify='left', values=('boxcar','triang','blackman','hamming','hann','bartlett','flattop','parzen','bohman','blackmanharris','nuttall','barthann','cosine','exponential','tukey','taylor'), state='readonly')
	ctrl_win1b_win.current(3)
	ctrl_win1b_win.grid(row=irow, column=7, sticky='we')
	tk.Button(tbl_gen, text="CHOOSE", command=choose_win1b).grid(row=irow, column=8, padx=5, sticky='e')
	tk.Label(tbl_gen, text='Win 2 : input Freq. (0 and '+str(sr/2)+' must be included) and gain pairs (both are separated by ","), order , window').grid(columnspan=9, row=(irow:=irow+1), column=0, sticky='w')
	tk.Label(tbl_gen, anchor='w', text='Freq :').grid(row=(irow:=irow+1), column=0, sticky='we')
	ctrl_win2_freq=tk.Entry(tbl_gen, width=100)
	ctrl_win2_freq.grid(row=irow, column=1, columnspan=8, sticky='w')
	tk.Label(tbl_gen, anchor='w', text='Gain :').grid(row=(irow:=irow+1), column=0, sticky='we')
	ctrl_win2_gain=tk.Entry(tbl_gen, width=100)
	ctrl_win2_gain.grid(row=irow, column=1, columnspan=8, sticky='w')
	tk.Label(tbl_gen, anchor='e', text='Order :').grid(row=(irow:=irow+1), column=4, sticky='we')
	ctrl_win2_order=tk.Entry(tbl_gen, width=10)
	ctrl_win2_order.grid(row=irow, column=5, sticky='w')
	tk.Label(tbl_gen, anchor='e', text=' Window : ').grid(row=irow, column=6, sticky='we')
	ctrl_win2_win=ttk.Combobox(tbl_gen, justify='left', values=('boxcar','triang','blackman','hamming','hann','bartlett','flattop','parzen','bohman','blackmanharris','nuttall','barthann','cosine','exponential','tukey','taylor'), state='readonly')
	ctrl_win2_win.current(3)
	ctrl_win2_win.grid(row=irow, column=7, sticky='we')
	tk.Button(tbl_gen, text="CHOOSE", command=choose_win2).grid(row=irow, column=8, padx=5, sticky='e')
	tbl_coef=ttk.Frame(dlg, padding=(0,10,0,0))
	tbl_coef.pack(side='top', fill='x', ipadx=5, ipady=5)
	var_coef=tk.StringVar(value='')
	tk.Label(tbl_coef, anchor='w', text='Coef :').grid(row=0, column=0, sticky='we')
	tk.Entry(tbl_coef, width=100, textvariable=var_coef).grid(row=0, column=1, sticky='we')
	btn_ok=tk.Button(dlg, text="  OK  ", command=dofilter)
	btn_ok.pack(side='right', padx=5, anchor='n', pady=5)
	tk.Button(dlg, text="  Show Freq. Response  ", command=show_freq).pack(side='right', padx=(5,0), anchor='n', pady=5)
	tk.Button(dlg, text="CANCEL", command=lambda: pyplot.close('all') is dlg.destroy()).pack(side='right', anchor='n', pady=5)
	global data
	btn_ok['state']='normal' if data is not None and len(data)>0 else 'disabled'
	dlg.protocol("WM_DELETE_WINDOW", lambda: pyplot.close('all') is dlg.destroy())

if __name__=='__main__':
	win.mainloop()

